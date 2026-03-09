# Release Checklist (Quick)

This repo contains a Django backend (`backend/`) and a Flutter app (`mobile/`).

## Backend

- Set production env vars (see `backend/.env.example`).
- Use Postgres in production (`DATABASE_URL=postgresql://...`).
- Run: `python manage.py migrate`
- Run: `python manage.py check --deploy`
- Serve via a real WSGI server (e.g. gunicorn/uvicorn behind Nginx) and enable HTTPS.
- Configure static/media hosting (S3, CDN, or Nginx volumes), then run `python manage.py collectstatic`.

See `backend/DEPLOYMENT.md` for a longer checklist.

## Mobile (Flutter)

- Set the app name/branding (Android + iOS).
- Configure Android release signing (`mobile/android/key.properties`).
- Increment `version:` in `mobile/pubspec.yaml`.
- Run: `flutter test`
- Build release artifacts:
  - Android: `flutter build appbundle --release`
  - iOS: build/archive in Xcode for App Store distribution

See `mobile/RELEASE.md` for details.

