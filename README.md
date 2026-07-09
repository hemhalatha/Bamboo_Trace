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

Backend deployment should run the FastAPI app with Uvicorn or a production ASGI server setup. Example process command:

```powershell
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Set production environment variables in the deployment platform, not in committed files.

## Important Clarification

The backend is not Node.js. There is no Express/Firebase Functions backend in the current codebase. Any previous `npm run dev` command was only an NPM wrapper around `uvicorn`; that wrapper has been removed to avoid deployment and developer confusion.
