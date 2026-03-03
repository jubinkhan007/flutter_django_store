from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import timedelta
from typing import Any

import requests
from django.db import transaction
from django.utils import timezone

from ..models import CourierIntegration


class PathaoError(Exception):
    pass


@dataclass(frozen=True)
class PathaoCredentials:
    base_url: str
    client_id: str
    client_secret: str
    username: str
    password: str


def _env_for_mode(mode: str, name: str, default: str = '') -> str:
    mode_key = 'SANDBOX' if mode == CourierIntegration.Mode.SANDBOX else 'PROD'
    return os.getenv(f'PATHAO_{mode_key}_{name}', os.getenv(f'PATHAO_{name}', default))


def load_pathao_credentials(mode: str) -> PathaoCredentials:
    base_url_default = (
        'https://courier-api-sandbox.pathao.com'
        if mode == CourierIntegration.Mode.SANDBOX
        else 'https://api-hermes.pathao.com'
    )
    base_url = _env_for_mode(mode, 'BASE_URL', base_url_default).rstrip('/')
    client_id = _env_for_mode(mode, 'CLIENT_ID')
    client_secret = _env_for_mode(mode, 'CLIENT_SECRET')
    username = _env_for_mode(mode, 'USERNAME')
    password = _env_for_mode(mode, 'PASSWORD')
    if not all([base_url, client_id, client_secret, username, password]):
        raise PathaoError('Missing Pathao credentials in environment variables.')
    return PathaoCredentials(
        base_url=base_url,
        client_id=client_id,
        client_secret=client_secret,
        username=username,
        password=password,
    )


class PathaoClient:
    def __init__(self, integration: CourierIntegration):
        self.integration = integration
        self.creds = load_pathao_credentials(integration.mode)

    def _auth_headers(self) -> dict[str, str]:
        token = self._ensure_access_token()
        return {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}

    def _ensure_access_token(self) -> str:
        # Refresh with a small buffer.
        buffer_seconds = 120
        if self.integration.access_token and self.integration.expires_at:
            if self.integration.expires_at > timezone.now() + timedelta(seconds=buffer_seconds):
                return self.integration.access_token

        # Lock row to avoid thundering herd refresh.
        with transaction.atomic():
            locked = CourierIntegration.objects.select_for_update().get(id=self.integration.id)
            if locked.access_token and locked.expires_at:
                if locked.expires_at > timezone.now() + timedelta(seconds=buffer_seconds):
                    self.integration = locked
                    return locked.access_token

            token_data = self.issue_token()
            locked.access_token = token_data.get('access_token', '') or ''
            locked.refresh_token = token_data.get('refresh_token', '') or ''
            expires_in = int(token_data.get('expires_in') or 0)
            if expires_in <= 0:
                # Default to 55 minutes if API doesn't return expires_in.
                expires_in = 55 * 60
            locked.expires_at = timezone.now() + timedelta(seconds=expires_in)
            locked.save(update_fields=['access_token', 'refresh_token', 'expires_at', 'updated_at'])
            self.integration = locked
            return locked.access_token

    def _request(self, method: str, path: str, *, headers: dict[str, str] | None = None, params=None, json=None) -> Any:
        url = f'{self.creds.base_url}{path}'
        resp = requests.request(method, url, headers=headers, params=params, json=json, timeout=25)
        try:
            data = resp.json()
        except Exception:
            raise PathaoError(f'Invalid Pathao response ({resp.status_code}).')
        if resp.status_code >= 400:
            raise PathaoError(data.get('message') or data.get('error') or f'Pathao error ({resp.status_code}).')
        return data

    def issue_token(self) -> dict[str, Any]:
        payload = {
            'client_id': self.creds.client_id,
            'client_secret': self.creds.client_secret,
            'username': self.creds.username,
            'password': self.creds.password,
            'grant_type': 'password',
        }
        return self._request('POST', '/aladdin/api/v1/issue-token', headers={'Accept': 'application/json'}, json=payload)

    def list_stores(self) -> list[dict[str, Any]]:
        data = self._request('GET', '/aladdin/api/v1/stores', headers=self._auth_headers())
        return data.get('data') or []

    def list_cities(self) -> list[dict[str, Any]]:
        data = self._request('GET', '/aladdin/api/v1/city-list', headers=self._auth_headers())
        return data.get('data') or []

    def list_zones(self, city_id: int) -> list[dict[str, Any]]:
        data = self._request(
            'GET',
            '/aladdin/api/v1/zone-list',
            headers=self._auth_headers(),
            params={'city_id': city_id},
        )
        return data.get('data') or []

    def list_areas(self, zone_id: int) -> list[dict[str, Any]]:
        data = self._request(
            'GET',
            '/aladdin/api/v1/area-list',
            headers=self._auth_headers(),
            params={'zone_id': zone_id},
        )
        return data.get('data') or []

    def create_order(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = self._request('POST', '/aladdin/api/v1/orders', headers=self._auth_headers(), json=payload)
        return data.get('data') or data

    def order_info(self, consignment_id: str) -> dict[str, Any]:
        data = self._request(
            'GET',
            '/aladdin/api/v1/order/info',
            headers=self._auth_headers(),
            params={'consignment_id': consignment_id},
        )
        return data.get('data') or data
