# Azure VM Deployment Checklist

The deployment scripts run the Flutter web frontend and FastAPI backend in Docker
Compose on an Ubuntu Azure VM. PostgreSQL runs separately on Azure Database for
PostgreSQL Flexible Server.

## Azure VM

1. Create an Ubuntu 24.04 VM and restrict SSH access to trusted addresses.
2. Clone the repository and run the one-time VM setup:

   ```bash
   git clone https://github.com/hemhalatha/Bamboo_Trace.git
   cd Bamboo_Trace
   bash scripts/azure_vm_setup.sh
   ```

3. Configure DNS and HTTPS termination for the app domain before production
   use. The backend requires an HTTPS frontend origin. The VM's Nginx listens on
   HTTP, so put a trusted TLS-terminating service in front of the VM (or add TLS
   to Nginx) and restrict inbound HTTP to that service.
4. Ensure the VM can connect to the managed PostgreSQL server. Configure the
   server's networking/firewall to allow the VM, and keep TLS enabled.
5. After logging out and back in so the Docker group takes effect, configure
   the environment, initialize a new database if needed, then deploy:

   ```bash
   cp .env.azure.example .env
   nano .env
   bash scripts/initialize_managed_postgres.sh
   bash scripts/deploy.sh
   ```

   The initialization command is for a new database (or a reviewed schema
   change). It creates tables and runs the app's existing compatibility helpers;
   take a database backup before using it on an existing production database.
   Normal deployments keep `RUN_DB_STARTUP_TASKS=false`.

The Azure Compose file does not start a local database. It binds the backend
and frontend ports to localhost; Nginx exposes the app through the VM. PostgreSQL
credentials, the HTTPS origin, and the API URL must be set in `.env`. URL-encode
special characters in the database password.

## Backend

Runtime: Python FastAPI + Uvicorn

Required environment variables:

- `DATABASE_URL`: Azure Database for PostgreSQL connection string with
  `sslmode=require`.
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
- The VM's `backend-uploads` Docker volume persists across container redeployments,
  but is not a backup. Back it up or move uploads to durable object storage.

## Frontend

Runtime: Flutter web static build served by nginx.

Production build requires the public HTTPS API URL (for this deployment,
`https://<your-domain>/api`):

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
- Production env validation passes on the VM.
- Smoke test `/health`, login, product listing, order handover OTP, and upload flow.
