# Logistics (Phase 16)

This app adds automated courier provisioning + tracking updates for:
- Pathao (OAuth2, token cached in `CourierIntegration`)
- Steadfast (API key/secret)
- RedX (endpoint paths configurable via env)

## Environment variables
- Copy `backend/.env.example` → `backend/.env` and fill in credentials.
- `backend/config/settings.py` loads `backend/.env` in dev (does not override existing env vars).

## Key endpoints
- Vendor fulfill (auto): `POST /api/vendors/sub-orders/<id>/fulfill/`
  - Send: `auto_provision=true`, `courier_code=pathao|steadfast|redx`, optional `mode=SANDBOX|PROD`
  - For Pathao, include `store_id`, `recipient_city`, `recipient_zone`, `recipient_area`, `item_weight`
  - Response includes `provision_status` (REQUESTED/CREATED/FAILED) and `last_error`
- Pathao lookup (cached):
  - `GET /api/logistics/pathao/stores/`
  - `GET /api/logistics/pathao/cities/`
  - `GET /api/logistics/pathao/zones/?city_id=<id>`
  - `GET /api/logistics/pathao/areas/?zone_id=<id>`
- Webhooks:
  - `POST /api/logistics/webhooks/<courier>/` (optional `X-Webhook-Secret`)
- Retry provisioning (vendor):
  - `POST /api/logistics/sub-orders/<id>/retry/`

## Worker requirements
- Run a Celery worker + beat for:
  - async provisioning: `logistics.tasks.provision_suborder_task`
  - fallback polling: `logistics.tasks.poll_courier_updates_task` (every 30 minutes)

