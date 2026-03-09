# Backend Deployment Notes

This project uses Django + DRF.

## Minimum production settings

Set environment variables (see `backend/.env.example`):

- `DJANGO_ENV=production`
- `DJANGO_SECRET_KEY=...` (long random string)
- `DJANGO_ALLOWED_HOSTS=api.yourdomain.com`
- `DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DBNAME`
- `CORS_ALLOWED_ORIGINS=https://your-frontend.example`
- `CSRF_TRUSTED_ORIGINS=https://your-frontend.example`

Recommended:

- `SECURE_SSL_REDIRECT=true`
- `SESSION_COOKIE_SECURE=true`
- `CSRF_COOKIE_SECURE=true`
- `SECURE_HSTS_SECONDS=3600`
- `SECURE_HSTS_INCLUDE_SUBDOMAINS=true`
- `SECURE_HSTS_PRELOAD=false` (enable only when you’re ready)
- `USE_X_FORWARDED_PROTO=true` (when behind a reverse proxy terminating TLS)

## Basic runbook

From `backend/`:

- Install deps: `pip install -r requirements.txt`
- Migrate: `python manage.py migrate`
- Check: `python manage.py check --deploy`
- Create admin user: `python manage.py createsuperuser`
- Collect static: `python manage.py collectstatic`

## Serving

Use a process manager + reverse proxy in production (example approach):

- Run Django via gunicorn/uvicorn
- Put Nginx in front for TLS termination, gzip, and static/media

## Data

SQLite is fine for development, but use Postgres in production.

## Docker (VPS)

This repo includes a production-focused Docker Compose file at `docker-compose.prod.yml`
that runs:

- Django (gunicorn) on the internal network
- Postgres
- Caddy for HTTPS + reverse proxy + static/media serving

On your VPS:

1) Install Docker + Compose plugin
2) Clone the repo to `/srv/shopease`
3) Create `/srv/shopease/.env` (not committed) with at least:

```
POSTGRES_DB=shopease
POSTGRES_USER=shopease
POSTGRES_PASSWORD=change-me

DJANGO_SECRET_KEY=change-me-to-a-long-random-string
DJANGO_ALLOWED_HOSTS=shopease.chickenkiller.com
CORS_ALLOWED_ORIGINS=https://shopease.chickenkiller.com
CSRF_TRUSTED_ORIGINS=https://shopease.chickenkiller.com
```

Then:

```
cd /srv/shopease
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec -T web python manage.py migrate --noinput
docker compose -f docker-compose.prod.yml exec -T web python manage.py collectstatic --noinput
```
