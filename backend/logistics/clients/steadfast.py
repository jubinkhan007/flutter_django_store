from __future__ import annotations

import os
from typing import Any

import requests


class SteadfastError(Exception):
    pass


class SteadfastClient:
    """
    Steadfast (Packzy) API wrapper.
    Docs are commonly referenced as `https://portal.packzy.com/api/v1/...`.
    """

    def __init__(self, *, base_url: str | None = None, api_key: str | None = None, api_secret: str | None = None):
        self.base_url = (base_url or os.getenv('STEADFAST_BASE_URL', 'https://portal.packzy.com/api/v1')).rstrip('/')
        self.api_key = api_key or os.getenv('STEADFAST_API_KEY', os.getenv('STEADFAST_KEY', ''))
        self.api_secret = api_secret or os.getenv(
            'STEADFAST_API_SECRET',
            os.getenv('STEADFAST_SECRET', os.getenv('STEADFAST_SECRET_KEY', '')),
        )
        if not self.api_key or not self.api_secret:
            raise SteadfastError('Missing STEADFAST_API_KEY / STEADFAST_API_SECRET.')

    def _headers(self) -> dict[str, str]:
        return {
            'Api-Key': self.api_key,
            'Secret-Key': self.api_secret,
            'Accept': 'application/json',
        }

    def _request(self, method: str, path: str, *, json: dict[str, Any] | None = None, params=None) -> Any:
        url = f'{self.base_url}{path}'
        resp = requests.request(method, url, headers=self._headers(), json=json, params=params, timeout=25)
        try:
            data = resp.json()
        except Exception:
            raise SteadfastError(f'Invalid Steadfast response ({resp.status_code}).')
        if resp.status_code >= 400:
            raise SteadfastError(data.get('message') or data.get('error') or f'Steadfast error ({resp.status_code}).')
        return data

    def create_order(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._request('POST', '/create_order', json=payload)

    def status_by_consignment_id(self, consignment_id: str) -> dict[str, Any]:
        return self._request('GET', '/status_by_cid', params={'consignment_id': consignment_id})
