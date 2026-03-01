from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

import requests
from django.conf import settings


@dataclass(frozen=True)
class SSLCommerzRefundInitResult:
    api_connect: str
    bank_tran_id: str | None
    trans_id: str | None
    refund_ref_id: str | None
    status: str | None
    error_reason: str | None


@dataclass(frozen=True)
class SSLCommerzRefundStatusResult:
    api_connect: str
    bank_tran_id: str | None
    tran_id: str | None
    refund_ref_id: str | None
    initiated_on: str | None
    refunded_on: str | None
    status: str | None
    error_reason: str | None


class SSLCommerzRefundClient:
    """
    Minimal client for SSLCommerz refund APIs.

    Docs (provided by user):
      - Initiate refund: GET merchantTransIDvalidationAPI.php with bank_tran_id + refund_trans_id + refund_amount + refund_remarks
      - Query refund status: GET merchantTransIDvalidationAPI.php with refund_ref_id
    """

    def __init__(self):
        is_sandbox = getattr(settings, 'SSLCOMMERZ_IS_SANDBOX', True)
        base = 'https://sandbox.sslcommerz.com' if is_sandbox else 'https://securepay.sslcommerz.com'
        self.endpoint = f'{base}/validator/api/merchantTransIDvalidationAPI.php'
        self.store_id = getattr(settings, 'SSLCOMMERZ_STORE_ID', 'testbox')
        self.store_passwd = getattr(settings, 'SSLCOMMERZ_STORE_PASS', 'qwerty')

    def initiate_refund(
        self,
        *,
        bank_tran_id: str,
        refund_trans_id: str,
        refund_amount: Decimal,
        refund_remarks: str,
        refe_id: str | None = None,
    ) -> SSLCommerzRefundInitResult:
        params: dict[str, str] = {
            'bank_tran_id': bank_tran_id,
            'refund_trans_id': refund_trans_id,
            'refund_amount': f'{refund_amount:.2f}',
            'refund_remarks': refund_remarks,
            'store_id': self.store_id,
            'store_passwd': self.store_passwd,
            'format': 'json',
        }
        if refe_id:
            params['refe_id'] = refe_id

        resp = requests.get(self.endpoint, params=params, timeout=20)
        data = resp.json() if resp.content else {}

        return SSLCommerzRefundInitResult(
            api_connect=str(data.get('APIConnect') or ''),
            bank_tran_id=data.get('bank_tran_id'),
            trans_id=data.get('trans_id'),
            refund_ref_id=data.get('refund_ref_id'),
            status=data.get('status'),
            error_reason=data.get('errorReason') or data.get('error_reason'),
        )

    def query_refund_status(
        self,
        *,
        refund_ref_id: str,
    ) -> SSLCommerzRefundStatusResult:
        params: dict[str, str] = {
            'refund_ref_id': refund_ref_id,
            'store_id': self.store_id,
            'store_passwd': self.store_passwd,
            'format': 'json',
        }

        resp = requests.get(self.endpoint, params=params, timeout=20)
        data = resp.json() if resp.content else {}

        return SSLCommerzRefundStatusResult(
            api_connect=str(data.get('APIConnect') or ''),
            bank_tran_id=data.get('bank_tran_id'),
            tran_id=data.get('tran_id'),
            refund_ref_id=data.get('refund_ref_id'),
            initiated_on=data.get('initiated_on'),
            refunded_on=data.get('refunded_on'),
            status=data.get('status'),
            error_reason=data.get('errorReason') or data.get('error_reason'),
        )

