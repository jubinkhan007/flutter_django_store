# Returns / Refunds / RMA

## Overview

This app implements a vendor-scoped RMA workflow:

- Customers create a return/replace request for an order.
- If the order contains multiple vendors, the backend automatically splits the request into **one RMA per vendor**.
- Vendors approve/reject, schedule pickup / request drop-off, mark received, and initiate refunds.
- If the vendor does not respond in time, requests auto-escalate (see **Escalation timer**).

## Key settings

Configured in `backend/config/settings.py`:

- `RMA_DEFAULT_RETURN_WINDOW_DAYS` (default `7`)
- `RMA_VENDOR_RESPONSE_HOURS` (default `48`)

## Escalation timer (auto-escalate)

Return requests are created with `vendor_response_due_at = now + RMA_VENDOR_RESPONSE_HOURS`.

Run this periodically (cron/systemd timer/Celery beat/etc.):

```bash
cd backend
./venv/bin/python manage.py escalate_returns
```

It escalates `SUBMITTED` requests whose `vendor_response_due_at` has passed by setting:

- `status = ESCALATED`
- `escalated_at = now`

## Refund pipeline

- Wallet refunds complete immediately (wallet balance is credited, refund marked `COMPLETED`, return marked `REFUNDED`).
- Original-method refunds create a `Refund` record and set the return to `REFUND_PENDING`.
  - Without a payment-gateway integration/webhook, completion is manual via:
    - `POST /api/vendors/returns/<id>/refund/complete/` (optional `reference`)

