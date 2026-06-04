# BambooTrace

A supply-chain tracking app for bamboo products — Flutter frontend with Firebase backend (Firestore + Auth) and Firebase Cloud Functions providing authenticated REST endpoints.

## Table of contents
- [Project overview](#project-overview)
- [Key features](#key-features)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
- [Folder structure](#folder-structure)
- [API overview](#api-overview)
- [Database design](#database-design)
- [Authentication flow](#authentication-flow)
- [Local setup](#local-setup)
- [Environment variables & secrets](#environment-variables--secrets)
- [Development workflow](#development-workflow)
- [Testing](#testing)
- [Build & deployment](#build--deployment)
- [Security & validation](#security--validation)
- [Troubleshooting & notes](#troubleshooting--notes)
- [Verification log (repo audit)](#verification-log-repo-audit)

## Project overview

BambooTrace tracks batches, projects and orders for users. The Flutter app uses Firebase for authentication and Firestore for data. A small Express-based API is hosted as Firebase Cloud Functions to expose authenticated REST endpoints for operations that complement direct Firestore usage.

## Key features
- User authentication (Firebase Auth)
- Per-user Firestore collections: batches, projects, orders
- Authenticated REST endpoints (Cloud Functions) for CRUD on batches/projects/orders
- Flutter UI with screens for adding batches and viewing orders

Only features implemented in the repository are documented here.

## Tech stack
- Frontend: Flutter (Dart)
- Backend: Node.js + Express running as Firebase Cloud Functions
- Auth & DB: Firebase Auth, Cloud Firestore
- Dev tooling: Firebase CLI, nodemon (dev)

## Architecture

```mermaid
flowchart LR
  subgraph Client
    A[Flutter app] -- Firebase SDK --> B[Firebase Auth & Firestore]
    A -- REST --> C[Cloud Functions (Express API)]
  end
  C -- Admin SDK --> D[Firestore]
  B -- Direct reads/writes --> D
  C -- Verifies token with --> B
```

## Folder structure (top-level)
- [backend](backend) — Firebase functions + API (see [backend/functions/index.js](backend/functions/index.js#L1))
- [frontend](frontend) — Flutter app (entry: [frontend/lib/main.dart](frontend/lib/main.dart#L1))

Key frontend files:
- [frontend/lib/services/api_service.dart](frontend/lib/services/api_service.dart#L1) — REST client that attaches Firebase ID token
- [frontend/lib/services/auth_service.dart](frontend/lib/services/auth_service.dart#L1) — sign in / sign up / role handling
- [frontend/lib/services/database_service.dart](frontend/lib/services/database_service.dart#L1) — Firestore streams and helpers
- [frontend/lib/screens/farmer/add_batch_page.dart](frontend/lib/screens/farmer/add_batch_page.dart#L1) — example UI using `ApiService`

Key backend files:
- [backend/package.json](backend/package.json#L1)
- [backend/functions/index.js](backend/functions/index.js#L1) — Express app exported as `api` Cloud Function
- [backend/functions/controllers/*](backend/functions/controllers) — controller helpers used by API

## API overview

All Cloud Function endpoints require a Firebase ID token in the `Authorization: Bearer <token>` header. See authentication flow below.

- `GET /health` — health check
- `GET /batches` — list batches for authenticated user
- `POST /batches` — add batch (body: batch fields)
- `GET /projects` — list projects for authenticated user
- `POST /projects` — add project
- `GET /orders` — list orders for authenticated user
- `POST /orders` — add order

Example (fetch batches):

```
GET /batches
Authorization: Bearer <Firebase ID token>
```

Responses are JSON arrays or simple success objects (index.js and controllers implement straightforward add/list semantics).

## Database design

Firestore is used with a per-user subcollection pattern. Primary collections and document shapes observed:
- `users/{uid}` — user document: `email`, `name`, `role`, `createdAt`
- `users/{uid}/batches/{batchId}` — batch documents contain fields like `batchId`, `quantity`, `location`, `type`, `createdAt`
- `users/{uid}/projects/{projectId}` — project metadata with `createdAt`
- `users/{uid}/orders/{orderId}` — order documents with `productName`, `price`, `status`, `createdAt`

Models are lightly documented in code (see `frontend/lib/models/user.dart`). Several backend model files exist but are currently empty; see verification section.

## Authentication flow

1. User signs in via Firebase Auth in the Flutter app ([auth_service.dart](frontend/lib/services/auth_service.dart#L1)).
2. Client obtains an ID token from the signed-in `User` and `ApiService` attaches it to requests in the `Authorization: Bearer <token>` header ([api_service.dart](frontend/lib/services/api_service.dart#L1)).
3. The Express API middleware in [backend/functions/index.js](backend/functions/index.js#L1) verifies the token with `admin.auth().verifyIdToken(idToken)` and sets `req.user`.
4. Cloud Functions use `req.user.uid` to read/write under `users/{uid}` in Firestore.

## Local setup

Prerequisites:
- Flutter SDK (to run the frontend)
- Node.js (to run backend functions locally)
- Firebase CLI (for deploying functions)
- A Firebase project and service account or local emulator set up

Backend (local development):

1. Install dependencies:

```bash
cd backend
npm install
```

2. To run locally (simple Node run):

```bash
npm run dev
# or
npm start
```

Note: `index.js` calls `admin.initializeApp()` which expects either default application credentials or the Firebase emulator. For local service account use set `GOOGLE_APPLICATION_CREDENTIALS` to your service account JSON.

Frontend (local development):

1. From the repo root:

```bash
cd frontend
flutter pub get
flutter run
```

2. Firebase options: `frontend/lib/firebase_options.dart` is blank in this repository. Generate it with the FlutterFire CLI and follow the official setup steps, or populate the file from your Firebase project using `flutterfire configure`.

## Environment variables & secrets
- `GOOGLE_APPLICATION_CREDENTIALS` — path to service account JSON for local admin SDK usage (or use Firebase Emulator Suite)
- Firebase project configuration used by Flutter is expected in `frontend/lib/firebase_options.dart` (not checked into repo)

## Development workflow
- Frontend development: modify Dart files under `frontend/lib`, use `flutter run` or `flutter build`.
- Backend development: modify `backend/functions/index.js` (or controller modules). Use `npm run dev` for nodemon.
- Deploy backend functions with `npm run deploy` (requires Firebase CLI authenticated and project configured).

## Testing
- Frontend contains a basic Flutter widget test at `frontend/test/widget_test.dart`, but the test references `MyApp` and may be outdated relative to `main.dart` — the test likely needs updates to reflect current app entrypoints.
- No automated backend tests detected.

Run Flutter tests:

```bash
cd frontend
flutter test
```

## Build & deployment
- Frontend: standard Flutter build commands (e.g., `flutter build apk`, `flutter build ios`, `flutter build web`).
- Backend: `cd backend && npm run deploy` will run `firebase deploy --only functions` (ensure `firebase` CLI is authenticated and `firebase.json` is configured).

## Security & validation
- Implemented:
  - Firebase ID token verification in the Express middleware ([backend/functions/index.js](backend/functions/index.js#L1)).
  - `helmet()` is used for basic HTTP header protections.
  - `cors({ origin: true })` is configured for CORS handling.

- Areas to improve (observed in code):
  - Input validation middleware files exist but are empty (`backend/functions/middleware/validation_middleware.js`). Controllers accept request bodies without schema validation.
  - Several model files and controller stubs are empty; consistent server-side validation/schema enforcement is not present.

## Troubleshooting & notes
- If `frontend/lib/firebase_options.dart` is empty, the app will fail to initialize Firebase — run `flutterfire configure` or add the file from Firebase console.
- If Cloud Functions cannot access Firestore locally, set `GOOGLE_APPLICATION_CREDENTIALS` or run the Firebase Emulator Suite.
- The front-end `ApiService` uses a hard-coded placeholder base URL in some screens (see [frontend/lib/screens/farmer/add_batch_page.dart](frontend/lib/screens/farmer/add_batch_page.dart#L1)). Replace `https://your-backend-url/api` with your deployed Cloud Function URL (the function is exported as `api`). Example function URL: `https://<region>-<project>.cloudfunctions.net/api`.

## Verification log (repo audit)
The following items were verified against the repository and require attention or are absent:

- `frontend/lib/firebase_options.dart` — EMPTY (Firebase config missing)
- `backend/functions/controllers/auth_controller.js` — EMPTY
- `backend/functions/models/*.js` — model files exist but are EMPTY
- `backend/functions/middleware/*.js` — middleware files exist but are EMPTY
- `backend/firebase.json` — EMPTY (no firebase configuration present in repo)
- No Dockerfile or docker-compose files found in repository
- Tests: `frontend/test/widget_test.dart` appears outdated and may fail as it references `MyApp` while current app uses `BambooTraceApp`/`BambooTraceApp` entry

Please review the items above and populate missing Firebase config and server-side validation before considering this repository deployment-ready.

---

If you want, I can:
- add a Dockerfile and sample `docker-compose.yml` for local development,
- scaffold validation (Joi / express-validator) for the backend,
- or update the Flutter test to match the current app entrypoint.
