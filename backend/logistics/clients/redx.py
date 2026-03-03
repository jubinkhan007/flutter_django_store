from __future__ import annotations

import os
from typing import Any

import requests


class RedxError(Exception):
    pass


class RedxClient:
    """
    RedX API wrapper.

    Note: RedX endpoint paths vary across merchant integrations. To keep this
    integration deployable without hardcoding unknown paths, the endpoint paths
    can be overridden via environment variables:

      - REDX_{SANDBOX|PROD}_BASE_URL
      - REDX_{SANDBOX|PROD}_API_KEY
      - REDX_CREATE_PARCEL_PATH (default: /api/v1/parcels)
      - REDX_PARCEL_STATUS_PATH (default: /api/v1/parcels/{reference})
      - REDX_AREAS_PATH (optional)
    """

    def __init__(self, *, mode: str):
        mode_key = 'SANDBOX' if mode == 'SANDBOX' else 'PROD'
        base_url = os.getenv(f'REDX_{mode_key}_BASE_URL', os.getenv('REDX_BASE_URL', '')).strip()
        if base_url and not base_url.startswith(('http://', 'https://')):
            base_url = f'https://{base_url}'
        self.base_url = base_url.rstrip('/')
        self.api_key = os.getenv(f'REDX_{mode_key}_API_KEY', os.getenv('REDX_API_KEY', ''))
        self.create_path = os.getenv('REDX_CREATE_PARCEL_PATH', '/api/v1/parcels')
        self.status_path = os.getenv('REDX_PARCEL_STATUS_PATH', '/api/v1/parcels/{reference}')
        self.areas_path = os.getenv('REDX_AREAS_PATH', '')
        if not self.base_url or not self.api_key:
            raise RedxError('Missing REDX base url / api key.')

    def _headers(self) -> dict[str, str]:
        # Some RedX integrations use an API key header, others use a bearer token.
        # Heuristic: JWT-like tokens contain two dots.
        headers = {'Accept': 'application/json'}
        if self.api_key.count('.') >= 2:
            headers['Authorization'] = f'Bearer {self.api_key}'
        else:
            headers['Api-Key'] = self.api_key
        return headers

    def _request(self, method: str, path: str, *, json: dict[str, Any] | None = None, params=None) -> Any:
        url = f'{self.base_url}{path}'
        resp = requests.request(method, url, headers=self._headers(), json=json, params=params, timeout=25)
        try:
            data = resp.json()
        except Exception:
            raise RedxError(f'Invalid RedX response ({resp.status_code}).')
        if resp.status_code >= 400:
            raise RedxError(data.get('message') or data.get('error') or f'RedX error ({resp.status_code}).')
        return data

    def create_parcel(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._request('POST', self.create_path, json=payload)

    def parcel_status(self, reference: str) -> dict[str, Any]:
        path = self.status_path.format(reference=reference)
        return self._request('GET', path)

    def list_areas(self) -> list[dict[str, Any]]:
        if not self.areas_path:
            return []
        data = self._request('GET', self.areas_path)
        if isinstance(data, dict) and 'data' in data:
            return data.get('data') or []
        if isinstance(data, list):
            return data
        return []
