# Deployment Checklist

Use this checklist before promoting BambooTrace to production.

## Backend

Runtime: Python FastAPI + Uvicorn

Required environment variables:

- `DATABASE_URL`: PostgreSQL connection string from the deployment platform.
- `JWT_SECRET_KEY`: strong random secret, at least 32 characters.
- `JWT_ALGORITHM`: `HS256`, `HS384`, or `HS512`.
- `APP_ENV`: `production`.
- `ALLOWED_ORIGINS`: exactly one deployed HTTPS frontend origin.
- `ALLOWED_ORIGIN_REGEX`: empty in production.
- `RUN_DB_STARTUP_TASKS`: `false` in production.
- `ACCESS_TOKEN_EXPIRE_MINUTES`: token lifetime, defaults to `60`.

Start command for non-Docker hosts:

```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
```

Docker build/run example:

```bash
docker build -t bambootrace-api ./backend
docker run --env-file backend/.env -p 8000:8000 bambootrace-api
```

Production notes:

- Do not commit `.env` files.
- Serve the API only over HTTPS at the platform/load-balancer level.
- Use managed PostgreSQL backups before disabling startup schema helpers.
- Uploaded files under `backend/static/uploads` are local-disk based; use persistent disk or object storage for production durability.

## Frontend

Runtime: Flutter web static build served by nginx.

Production build requires `API_BASE_URL`:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com
```

Docker build example:

```bash
docker build \
  --build-arg API_BASE_URL=https://your-api.example.com \
  -t bambootrace-web \
  ./frontend
```

Production notes:

- `API_BASE_URL` must be HTTPS in release mode.
- `API_BASE_URL` must not be localhost, `127.0.0.1`, or `0.0.0.0` in release mode.
- Configure backend CORS `ALLOWED_ORIGINS` to exactly match the deployed frontend origin.

## Verification

Backend:

```bash
cd backend
python -m pytest -q -p no:cacheprovider
```

Frontend, when allowed:

```bash
cd frontend
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com
```

## Release Gate

Before merging/deploying:

- Backend tests pass.
- Frontend production build succeeds with the deployed API URL.
- No `.env` or generated cache/database files are tracked.
- Production env validation passes on the hosting platform.
- Smoke test `/health`, login, product listing, order handover OTP, and upload flow.
