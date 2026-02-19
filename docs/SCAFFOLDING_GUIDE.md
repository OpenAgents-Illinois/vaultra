# Vaultra — Scaffolding Guide for Coding Agents

> Step-by-step instructions for scaffolding the Vaultra application. Follow this order; each step depends on the previous.

**If you are a coding agent**: Start here. Execute phases 1–4 first to produce a runnable MVP. Phases 5–6 can follow. Cross-reference `docs/API_SCHEMAS.md`, `docs/BACKEND_SERVICES_SPEC.md`, and `docs/DATA_MODEL.md` for exact shapes and logic.

---

## Prerequisites

- Python 3.11+
- Node.js 18+
- Docker & Docker Compose
- PostgreSQL 15 (or use Docker)
- Redis (or use Docker)

---

## Phase 1: Project Structure

Create the following directory layout:

```
vaultra/
├── backend/                 # FastAPI application
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── auth/
│   │   ├── users/
│   │   ├── stripe/
│   │   ├── metrics/
│   │   ├── recommendations/
│   │   ├── agent/
│   │   ├── jobs/
│   │   └── shared/           # DB, deps, utils
│   ├── alembic/
│   ├── alembic.ini
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/                 # Astro application
│   ├── src/
│   │   ├── pages/
│   │   ├── components/
│   │   ├── layouts/
│   │   └── lib/
│   ├── public/
│   ├── astro.config.mjs
│   └── package.json
├── docs/                     # Specifications (existing)
├── infra/
│   └── k8s/                  # Kubernetes manifests (later)
├── docker-compose.yml
└── README.md
```

---

## Phase 2: Backend Scaffolding

### 2.1 Dependencies

**File**: `backend/requirements.txt`

```
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sqlalchemy[asyncio]>=2.0.0
asyncpg>=0.29.0
alembic>=1.13.0
pydantic>=2.5.0
pydantic-settings>=2.1.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
stripe>=8.0.0
pinecone-client>=3.0.0
openai>=1.10.0
redis>=5.0.0
arq>=0.25.0
httpx>=0.26.0
```

### 2.2 Config

**File**: `backend/app/config.py`

Load from env: `DATABASE_URL`, `REDIS_URL`, `JWT_SECRET`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_CONNECT_CLIENT_ID`, `PINECONE_API_KEY`, `PINECONE_INDEX`, `OPENAI_API_KEY`, `LLM_PROVIDER`, `OLLAMA_BASE_URL`, `OLLAMA_MODEL`. Use Pydantic Settings.

### 2.3 Database

**File**: `backend/app/shared/database.py`

- Async SQLAlchemy engine and session factory
- `Base` declarative base
- `get_db()` async generator for FastAPI Depends

**File**: `backend/alembic/env.py`

- Use async SQLAlchemy
- Import all models from `app.shared.database` so Alembic sees them

### 2.4 Models

Create SQLAlchemy models per `docs/DATA_MODEL.md`:

- `backend/app/shared/models.py` or per-module `models.py`:
  - `User`, `Business`, `UserBusinessMembership`, `IntegrationAccount`, `StripeEvent`, `FinancialMetricSnapshot`, `ReadinessScore`, `Recommendation`, `AgentConversation`, `AgentMessage`

### 2.5 Migrations

```bash
cd backend && alembic revision --autogenerate -m "initial_schema"
alembic upgrade head
```

### 2.6 Auth Module

**Files**: `backend/app/auth/schemas.py`, `backend/app/auth/service.py`, `backend/app/auth/router.py`

- Schemas: `SignupRequest`, `LoginRequest`, `TokenResponse`, `UserResponse`
- Service: `AuthService` with `signup`, `login`, `get_current_user` (see `docs/BACKEND_SERVICES_SPEC.md`)
- Router: POST /signup, POST /login, GET /me (protected)
- Dependency: `get_current_user` that validates JWT and returns User

### 2.7 Users Module

**Files**: `backend/app/users/schemas.py`, `backend/app/users/service.py`, `backend/app/users/router.py`

- Schemas: `UserProfile`, `BusinessCreate`, `BusinessUpdate`, `BusinessResponse`
- Service: `UsersService` per `docs/BACKEND_SERVICES_SPEC.md`
- Router: GET /users/me, PATCH /users/me, POST /users/businesses, PATCH /users/businesses/{id}

### 2.8 Stripe Module

**Files**: `backend/app/stripe/schemas.py`, `backend/app/stripe/service.py`, `backend/app/stripe/router.py`

- Service: `StripeService` per `docs/BACKEND_SERVICES_SPEC.md`
- Router: GET /integrations/stripe/connect, GET /integrations/stripe/callback, GET /integrations/stripe/status, POST /webhooks/stripe (no auth)

### 2.9 Metrics Module

**Files**: `backend/app/metrics/schemas.py`, `backend/app/metrics/service.py`, `backend/app/metrics/router.py`

- Service: `MetricsService` per `docs/BACKEND_SERVICES_SPEC.md`
- Router: GET /metrics, GET /metrics/history, GET /readiness, GET /readiness/history

### 2.10 Recommendations Module

**Files**: `backend/app/recommendations/schemas.py`, `backend/app/recommendations/service.py`, `backend/app/recommendations/router.py`

- Service: `RecommendationsService` per `docs/BACKEND_SERVICES_SPEC.md`
- Router: GET /recommendations, PATCH /recommendations/{id}

### 2.11 Agent Module

**Files**: `backend/app/agent/schemas.py`, `backend/app/agent/service.py`, `backend/app/agent/router.py`

- Service: `AgentService` per `docs/BACKEND_SERVICES_SPEC.md`
- MCP tools: `get_readiness_breakdown`, `get_top_recommendations`, `get_metric_summary`, `search_knowledge`
- Router: POST /agent/chat, GET /agent/conversations/{id}

### 2.12 Main App

**File**: `backend/app/main.py`

- FastAPI app
- Include all routers under prefix `/api/v1`
- CORS middleware
- Exception handlers for 400, 401, 403, 404, 500
- Health check: GET /health → `{"status": "ok"}`

---

## Phase 3: Frontend Scaffolding

### 3.1 Initialize Astro

```bash
cd frontend && npm create astro@latest . -- --template minimal --install --no-git
npm add @astrojs/react @astrojs/tailwind react react-dom
npm add chart.js react-chartjs-2
```

### 3.2 Config

**File**: `frontend/astro.config.mjs`

- Integrations: `react()`, `tailwind()`
- Output: `static` (or `server` if you prefer SSR)

### 3.3 Lib

**File**: `frontend/src/lib/auth.ts`

```typescript
const TOKEN_KEY = 'vaultra_token';
const BUSINESS_KEY = 'vaultra_current_business_id';

export function getToken(): string | null { ... }
export function setToken(token: string): void { ... }
export function removeToken(): void { ... }
export function getCurrentBusinessId(): string | null { ... }
export function setCurrentBusinessId(id: string): void { ... }
export function isAuthenticated(): boolean { ... }
export function getAuthHeaders(): HeadersInit { ... }
```

**File**: `frontend/src/lib/api.ts`

Implement all API functions per `docs/API_SCHEMAS.md` and `docs/ARCHITECTURE.md`:
- `signup`, `login`, `getCurrentUser`
- `getUserProfile`, `createBusiness`, `updateBusiness`
- `getLatestMetrics`, `getMetricHistory`, `getReadinessScore`, `getReadinessHistory`
- `getRecommendations`, `updateRecommendationStatus`
- `chatWithAgent`, `getConversation`
- `initiateStripeConnect`, `getStripeStatus`

Use `API_BASE = import.meta.env.PUBLIC_API_URL || 'http://localhost:8000/api/v1'`.

### 3.4 Layouts

**File**: `frontend/src/layouts/BaseLayout.astro`

- HTML shell, Tailwind, meta tags

**File**: `frontend/src/layouts/DashboardLayout.astro`

- Sidebar/header with nav, BusinessSelector (if 2+ businesses), logout
- Slot for page content

### 3.5 Components

Create per `docs/ARCHITECTURE.md` and `docs/IMPLEMENTATION_SPEC.md`:

- `ScoreCard.astro` — props: score, tier, trend
- `MetricsChart.tsx` — React island, Chart.js
- `RecommendationList.tsx` — React island
- `AgentChat.tsx` — React island
- `BusinessSelector.tsx` — React island
- `DashboardGuard.tsx` — React island, redirects if no token
- `Navigation.astro`

### 3.6 Pages

**Public**:
- `src/pages/index.astro` — Landing
- `src/pages/auth/login.astro` — Login form
- `src/pages/auth/signup.astro` — Signup form
- `src/pages/auth/callback.astro` — OAuth callback (Google)

**Protected** (wrap in DashboardGuard or layout that checks auth):
- `src/pages/onboarding/business.astro` — Business profile form
- `src/pages/onboarding/stripe-connect.astro` — "Connect Stripe" button + redirect
- `src/pages/dashboard/index.astro` — ScoreCard, metrics summary, quick recs
- `src/pages/dashboard/recommendations.astro` — RecommendationList
- `src/pages/dashboard/metrics.astro` — MetricsChart
- `src/pages/dashboard/agent.astro` — AgentChat

---

## Phase 4: Docker & Local Dev

### 4.1 docker-compose.yml

```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: vaultra
      POSTGRES_PASSWORD: vaultra
      POSTGRES_DB: vaultra
    ports: ["5432:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
  redis:
    image: redis:7
    ports: ["6379:6379"]
  backend:
    build: ./backend
    ports: ["8000:8000"]
    environment:
      DATABASE_URL: postgresql+asyncpg://vaultra:vaultra@postgres:5432/vaultra
      REDIS_URL: redis://redis:6379
    depends_on: [postgres, redis]
volumes:
  postgres_data:
```

### 4.2 Backend Dockerfile

- `FROM python:3.11-slim`
- Install deps, copy app, `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]`

---

## Phase 5: RAG Knowledge Base (Optional for MVP)

Create placeholder markdown files in `backend/docs/knowledge/`:

- `funding-readiness-factors.md`
- `reducing-chargebacks.md`
- `revenue-stability.md`
- `payout-timing.md`
- `readiness-score-explained.md`

Ingestion script: chunk → embed (OpenAI) → upsert Pinecone. Run once or via CI.

---

## Phase 6: Background Jobs (Optional for MVP)

- Use ARQ with Redis
- Define jobs: `stripe_sync`, `compute_metrics`, `compute_readiness`, `generate_recommendations`
- Worker entrypoint: `arq app.jobs.worker.WorkerSettings`
- For local dev: run worker in separate process or stub jobs

---

## Validation Checklist

Before considering scaffolding complete:

- [ ] All API endpoints return correct shapes per `docs/API_SCHEMAS.md`
- [ ] Auth: signup, login, protected routes work
- [ ] Business CRUD and membership checks work
- [ ] Stripe connect flow (redirects) works (requires Stripe dev account)
- [ ] Metrics/readiness endpoints return data (may be empty until Stripe connected + jobs run)
- [ ] Recommendations endpoints work
- [ ] Agent chat endpoint works (requires LLM + Pinecone or stubs)
- [ ] Frontend: all pages render, auth flow works, dashboard shows data when available
- [ ] Docker Compose brings up backend + postgres + redis

---

## Reference Documents

| Need | Document |
|------|----------|
| API shapes | `docs/API_SCHEMAS.md` |
| Service logic | `docs/BACKEND_SERVICES_SPEC.md` |
| DB schemas | `docs/DATA_MODEL.md` |
| Frontend structure | `docs/ARCHITECTURE.md` (Frontend Structure) |
| Implementation patterns | `docs/IMPLEMENTATION_SPEC.md` |
| Full spec index | `docs/SPECIFICATION_INDEX.md` |
