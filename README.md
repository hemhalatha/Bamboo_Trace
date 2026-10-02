# BambooTrace

BambooTrace is a full-stack bamboo supply-chain and artisan commerce app. It connects farmers, artisans, and customers so bamboo batches, products, custom requests, and handover-based orders can be managed with traceability.

## Tech Stack

- Frontend: Flutter / Dart
- Backend: Python FastAPI served by Uvicorn
- Database: PostgreSQL through SQLAlchemy
- Authentication: App-managed JWT auth
- File uploads: FastAPI static uploads under `backend/static/uploads`

## Repository Structure

```text
backend/   Python FastAPI API, SQLAlchemy models, routers, tests
frontend/  Flutter app
```

Important backend files:

- `backend/app/main.py` - FastAPI app entrypoint
- `backend/app/core/config.py` - environment validation and CORS settings
- `backend/app/core/database.py` - SQLAlchemy engine/session and startup schema helpers
- `backend/app/models.py` - database models
- `backend/app/schemas.py` - request/response schemas
- `backend/app/routers/` - API routers
- `backend/requirements.txt` - Python dependencies

Important frontend files:

- `frontend/lib/main.dart` - Flutter entrypoint
- `frontend/lib/config/app_config.dart` - API base URL configuration
- `frontend/lib/services/api_service.dart` - API client
- `frontend/lib/services/auth_service.dart` - auth/session state
- `frontend/lib/screens/` - role-based screens

## Backend Setup

From the repository root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

Create `backend/.env` from `backend/.env.example` and set real local values:

```env
DATABASE_URL=postgresql://user:password@localhost:5432/bambootrace
JWT_SECRET_KEY=change-this-to-a-long-random-development-secret
JWT_ALGORITHM=HS256
APP_ENV=development
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
ALLOWED_ORIGIN_REGEX=^https?://(localhost|127\.0\.0\.1)(:\d+)?$
RUN_DB_STARTUP_TASKS=true
```

Run the backend directly with Python/Uvicorn:

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health check:

```text
GET http://localhost:8000/health
```

## Frontend Setup

From the repository root:

```powershell
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

For production Flutter builds, provide a deployed HTTPS API URL:

```powershell
flutter build web --dart-define=API_BASE_URL=https://your-api.example.com
```

Production builds must not use localhost. `frontend/lib/config/app_config.dart` validates this.

## Docker Setup

The repository includes production-oriented Docker assets for PostgreSQL, the FastAPI API, and the Flutter web frontend. It is recommended to use Docker for local development testing and production deployments.

### 1. Environment Configuration

Create a root `.env` file from the checked-in example. This file will be ignored by Git to keep your secrets safe.

```bash
cp .env.example .env
```

**For Production:** Update at least these values before building images:

```env
POSTGRES_PASSWORD=replace-with-a-strong-database-password
DATABASE_URL=postgresql://bambootrace:replace-with-a-strong-database-password@db:5432/bambootrace
JWT_SECRET_KEY=replace-with-at-least-32-random-characters
API_BASE_URL=https://api.your-domain.example
ALLOWED_ORIGINS=https://your-frontend-domain.example
APP_ENV=production
ALLOWED_ORIGIN_REGEX=
RUN_DB_STARTUP_TASKS=false  # Set to true only on first run to create schemas
```

### 2. Starting the Stack

Start the full stack in detached mode (background):

```bash
docker compose up --build -d
```

*(Tip: If this is your first time or you want to see real-time logs from all services, omit the `-d` flag: `docker compose up --build`)*

### 3. Accessing the Application

Default published ports:

- **Frontend App**: [http://localhost:8080](http://localhost:8080)
- **Backend API Docs**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **PostgreSQL Database**: `localhost:5432`

### 4. Useful Docker Commands

**Checking Status & Logs:**
```bash
docker compose ps                 # View running containers and health status
docker compose logs -f            # Tail logs for all services
docker compose logs -f backend    # Tail logs for just the backend API
curl http://localhost:8000/health # Check backend health endpoint
```

**Rebuilding & Updating:**
```bash
# Rebuild a specific service after making code changes (e.g., frontend)
docker compose up -d --build frontend

# Restart a service without rebuilding
docker compose restart backend
```

**Database & Volumes:**
Persistent Docker volumes are automatically created for PostgreSQL data and backend uploads.
- `postgres-data` -> PostgreSQL database files
- `backend-uploads` -> `/app/static/uploads`

```bash
# Execute a command inside the running backend container (e.g., run tests)
docker compose exec backend python -m pytest

# Stop all services safely
docker compose down

# WARNING: Stop all services AND completely wipe database/upload data
docker compose down -v
```

### Docker Production Notes

- The backend image runs as a non-root user and exposes `/health` for container health checks.
- The frontend image is a multi-stage Flutter web build served by non-root nginx on port `8080`.
- `API_BASE_URL` is compiled into the Flutter web build. Rebuild the frontend image when the API URL changes.
- Release-mode Flutter builds in this codebase require `API_BASE_URL` to be a full HTTPS URL and reject local origins. Keep that validation for production deploys.
- Put TLS termination in front of the containers with your platform load balancer or reverse proxy.
- Do not use the placeholder secrets from `.env.example` in production.

## API Overview

Authentication endpoints:

- `POST /auth/signup`
- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/me`

Core endpoints are grouped by router:

- `/batches` - bamboo batch management
- `/projects` - artisan product/project listings
- `/orders` - product/material orders and handover OTP flow
- `/order-requests` - order request workflow
- `/custom-order-requests` - made-to-order request workflow
- `/dashboard` - role dashboard counts
- `/notifications` - notifications
- `/users` - profile/user data
- `/uploads` - upload handling
- `/static/uploads/...` - static uploaded files

Most application endpoints require an `Authorization: Bearer <jwt>` header after login/signup.

## Environment And Security Notes

- `.env` and `.env.*` are ignored by Git.
- Do not commit real secrets.
- Production requires a strong `JWT_SECRET_KEY`.
- Production CORS must allow exactly one deployed HTTPS frontend origin.
- `ALLOWED_ORIGIN_REGEX` must be empty in production.
- `RUN_DB_STARTUP_TASKS=false` is required in production.
- Uploaded files are served from `backend/static/uploads`.

## Testing

Backend targeted tests:

```powershell
cd backend
python -m pytest tests/test_order_requests.py -q -p no:cacheprovider
```

Full backend tests:

```powershell
cd backend
python -m pytest -q -p no:cacheprovider
```

Frontend checks, when allowed:

```powershell
cd frontend
flutter analyze
flutter test
```

## Deployment Notes

See [DEPLOYMENT.md](DEPLOYMENT.md) for the release checklist, Docker commands, required production environment variables, and smoke-test steps.

Backend deployment should run the FastAPI app with Uvicorn or a production ASGI server setup. Example process command:

```powershell
python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
```

Set production environment variables in the deployment platform, not in committed files.

## Important Clarification

The backend is not Node.js. There is no Express/Firebase Functions backend in the current codebase. Any previous `npm run dev` command was only an NPM wrapper around `uvicorn`; that wrapper has been removed to avoid deployment and developer confusion.
