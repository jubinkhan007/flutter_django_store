from __future__ import annotations

import base64
import json
import os
import subprocess
import tempfile
import time
from dataclasses import dataclass

import requests
from django.conf import settings


_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'
_TOKEN_AUD = 'https://oauth2.googleapis.com/token'
_TOKEN_URL = 'https://oauth2.googleapis.com/token'


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')


def _json_b64url(obj: dict) -> str:
    return _b64url(json.dumps(obj, separators=(',', ':'), ensure_ascii=False).encode('utf-8'))


def _load_service_account() -> dict:
    raw = getattr(settings, 'FCM_SERVICE_ACCOUNT_JSON', '') or ''
    path = getattr(settings, 'FCM_SERVICE_ACCOUNT_FILE', '') or ''

    if raw.strip():
        return json.loads(raw)

    if path.strip():
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)

    raise RuntimeError('FCM service account is not configured (set FCM_SERVICE_ACCOUNT_JSON or FCM_SERVICE_ACCOUNT_FILE).')


def _openssl_rs256_sign(private_key_pem: str, signing_input: str) -> str:
    """
    Signs `signing_input` (ASCII) with RS256 using OpenSSL.

    This avoids requiring `cryptography`/`google-auth` in the environment.
    """
    key_file = None
    try:
        key_file = tempfile.NamedTemporaryFile('w', delete=False)
        os.chmod(key_file.name, 0o600)
        key_file.write(private_key_pem)
        key_file.flush()
        key_file.close()

        proc = subprocess.run(
            ['openssl', 'dgst', '-sha256', '-sign', key_file.name],
            input=signing_input.encode('utf-8'),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        return _b64url(proc.stdout)
    finally:
        if key_file is not None:
            try:
                os.unlink(key_file.name)
            except Exception:
                pass


@dataclass
class FCMAccessToken:
    value: str
    expires_at: float  # epoch seconds


class FCMV1Client:
    _cached_token: FCMAccessToken | None = None

    def __init__(self):
        self.project_id = getattr(settings, 'FCM_PROJECT_ID', '') or ''
        if not self.project_id.strip():
            raise RuntimeError('FCM_PROJECT_ID is not configured.')

        self.sa = _load_service_account()
        self.client_email = self.sa.get('client_email') or ''
        self.private_key = self.sa.get('private_key') or ''
        if not self.client_email or not self.private_key:
            raise RuntimeError('Invalid service account JSON: missing client_email/private_key.')

    def _get_access_token(self) -> str:
        now = time.time()
        cached = self._cached_token
        if cached and cached.expires_at - 60 > now:
            return cached.value

        iat = int(now)
        exp = iat + 3600
        header = {'alg': 'RS256', 'typ': 'JWT'}
        claims = {
            'iss': self.client_email,
            'scope': _SCOPE,
            'aud': _TOKEN_AUD,
            'iat': iat,
            'exp': exp,
        }

        signing_input = f'{_json_b64url(header)}.{_json_b64url(claims)}'
        signature = _openssl_rs256_sign(self.private_key, signing_input)
        assertion = f'{signing_input}.{signature}'

        resp = requests.post(
            _TOKEN_URL,
            data={
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': assertion,
            },
            timeout=20,
        )
        data = resp.json() if resp.content else {}
        if resp.status_code != 200:
            raise RuntimeError(f'Failed to get OAuth token: {data}')

        token = data.get('access_token') or ''
        expires_in = int(data.get('expires_in') or 3600)
        if not token:
            raise RuntimeError(f'Invalid OAuth token response: {data}')

        self._cached_token = FCMAccessToken(value=token, expires_at=now + expires_in)
        return token

    def send_to_token(self, *, token: str, payload: dict) -> tuple[bool, dict]:
        access = self._get_access_token()
        url = f'https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send'

        msg = {
            'message': {
                'token': token,
                'notification': {
                    'title': payload.get('title', ''),
                    'body': payload.get('body', ''),
                },
                'android': {
                    'notification': {
                        'channel_id': 'shopease_default',
                    },
                },
                'apns': {
                    'payload': {
                        'aps': {
                            'sound': 'default',
                        }
                    }
                },
                'data': {k: str(v) for k, v in payload.items() if v is not None},
            }
        }

        resp = requests.post(
            url,
            headers={'Authorization': f'Bearer {access}', 'Content-Type': 'application/json'},
            json=msg,
            timeout=20,
        )

        try:
            data = resp.json()
        except Exception:
            data = {'raw': resp.text[:1000], 'status_code': resp.status_code}

        return resp.status_code == 200, data
