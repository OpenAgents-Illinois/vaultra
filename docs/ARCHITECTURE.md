# Vaultra — Architecture Specification

> Service boundaries, API contracts, and deployment layout. Spec-driven; implementation follows.

## Architecture Style

**Modular monolith** for MVP: single FastAPI app with clear module boundaries, deployable as one service. Path to split into microservices exists if scale demands it.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           VAULTRA APP                                  │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────────┤
│   auth      │   users     │   stripe    │  metrics    │   agent         │
│   module    │   module    │   module    │  module     │   module        │
├─────────────┴─────────────┴─────────────┴─────────────┴─────────────────┤
│                     Shared: DB, Redis, Pinecone, Stripe SDK             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Module Boundaries

| Module | Responsibility | Dependencies |
|--------|----------------|--------------|
| **auth** | Login, signup, JWT, OAuth callback, session | users |
| **users** | User CRUD, business profile, membership | — |
| **stripe** | OAuth connect, webhooks, data sync to DB | users |
| **metrics** | Compute metrics from raw Stripe data, readiness score | stripe |
| **recommendations** | Rules engine, generate recommendations from metrics | metrics |
| **agent** | MCP server, LLM orchestration, RAG (Pinecone), tools | metrics, recommendations |
| **jobs** | Scheduled tasks (CronJobs or in-process scheduler) | stripe, metrics, recommendations |

---

## API Surface

### Public REST API (consumed by Astro frontend)

Base path: `/api/v1`

### Business ID Resolution & Authorization

**JWT payload** (decoded): `{ user_id: UUID, email: string, exp: number }`

**Business-scoped endpoints** require `business_id` from one of:
- **Query param**: `?business_id=<uuid>` (e.g., GET /metrics, GET /readiness)
- **Path param**: `/users/businesses/{id}` (e.g., PATCH business)
- **Request body**: `{ business_id: "<uuid>", ... }` (e.g., POST /agent/chat)

**Authorization rule**: Before any business-scoped operation, verify the authenticated user is a member of that business via `user_business_memberships`. Return `403 Forbidden` if not.

**Default business** (for UX):
- If user has exactly one business: frontend may omit `business_id` and backend infers it.
- If user has multiple businesses: `business_id` is **required**; frontend must pass it (from URL, selector, or localStorage `vaultra_current_business_id`).
- Endpoint `GET /users/me` returns `businesses: [{ id, name, role }]` so frontend can populate a business selector.

#### Authentication Endpoints

| Method | Path | Module | Description | Request Body | Response |
|--------|------|--------|-------------|--------------|----------|
| POST | /auth/signup | auth | Create account | `{email, password, name}` | `{user: {...}, token: "..."}` |
| POST | /auth/login | auth | Login, return JWT | `{email, password}` | `{user: {...}, token: "..."}` |
| GET | /auth/callback/google | auth | OAuth callback | Query: `code, state` | Redirect or `{user, token}` |
| GET | /auth/me | auth | Current user (requires auth) | — | `{id, email, name, businesses: [...]}` |

#### User & Business Endpoints

| Method | Path | Module | Description | Request Body | Response |
|--------|------|--------|-------------|--------------|----------|
| GET | /users/me | users | Current user + businesses | — | `{id, email, name, businesses: [{id, name, role}]}` |
| PATCH | /users/me | users | Update profile | `{name?, avatar_url?}` | Updated user object |
| POST | /users/businesses | users | Create business | `{name, legal_entity?, industry?, revenue_estimate?, founded_at?}` | `{id, name, ...}` |
| PATCH | /users/businesses/{id} | users | Update business | `{name?, legal_entity?, ...}` | Updated business object |

#### Stripe Integration Endpoints

| Method | Path | Module | Description | Query Params | Response |
|--------|------|--------|-------------|--------------|----------|
| GET | /integrations/stripe/connect | stripe | Initiate Stripe OAuth | `business_id` | Redirect to Stripe |
| GET | /integrations/stripe/callback | stripe | Stripe OAuth callback | `code, state, business_id` | Redirect to dashboard |
| GET | /integrations/stripe/status | stripe | Connection status | `business_id` | `{connected: bool, account_id?, last_synced_at?}` |
| POST | /webhooks/stripe | stripe | Stripe webhook receiver | — | `200 OK` (no auth) |

#### Metrics & Readiness Endpoints

| Method | Path | Module | Description | Query Params | Response |
|--------|------|--------|-------------|--------------|----------|
| GET | /metrics | metrics | Latest metrics for business | `business_id` | `{revenue_total, volatility, chargeback_ratio, ...}` |
| GET | /metrics/history | metrics | Time-series metrics | `business_id, start_date?, end_date?` | `{metrics: [...]}` |
| GET | /readiness | metrics | Current score + tier | `business_id` | `{score: 0-100, tier, components: {...}}` |
| GET | /readiness/history | metrics | Score history | `business_id, limit?` | `{scores: [...]}` |

#### Recommendations Endpoints

| Method | Path | Module | Description | Query Params | Request Body | Response |
|--------|------|--------|-------------|--------------|--------------|----------|
| GET | /recommendations | recommendations | List for business | `business_id, status?, priority?` | — | `{recommendations: [...]}` |
| PATCH | /recommendations/{id} | recommendations | Update status | — | `{status: "accepted"\|"dismissed"}` | Updated recommendation |

#### Agent Endpoints

| Method | Path | Module | Description | Request Body | Response |
|--------|------|--------|-------------|--------------|----------|
| POST | /agent/chat | agent | Send message, get reply | `{business_id, message, conversation_id?}` | `{conversation_id, message_id, response, tool_calls?}` |
| GET | /agent/conversations/{id} | agent | Conversation history | — | `{id, messages: [{role, content, created_at}]}` |

### Internal (MCP tools — agent calls these)

These are exposed as MCP tools, not REST. Backed by the same FastAPI services.

| Tool | Purpose | Reads from |
|------|---------|------------|
| `get_readiness_breakdown` | Score components, what helps/hurts | metrics, readiness |
| `get_top_recommendations` | Top N recs for business | recommendations |
| `get_metric_summary` | Revenue, volatility, chargebacks | metrics |
| `get_business_context` | Business profile, industry | users |
| `search_knowledge` | RAG query to Pinecone | Pinecone index |

---

## Stripe Integration Flow

**Stripe Connect mode**: **Standard** (OAuth Connect). Platform uses OAuth to link to the business's Stripe account; we read charges, payouts, disputes via Stripe API with the connected account's access. Express is not used.

```
User clicks "Connect Stripe"
    → GET /integrations/stripe/connect
    → Redirect to Stripe OAuth
    → User authorizes
    → GET /integrations/stripe/callback?code=...
    → Exchange code for account_id, store in integration_accounts
    → Enqueue backfill job

Webhook: charge.created, payout.paid, etc.
    → POST /webhooks/stripe (verified by signature)
    → Append to stripe_events (raw) or update aggregates
    → Idempotent by event ID
```

---

## Background Jobs

| Job | Schedule | Module | Action |
|-----|----------|--------|--------|
| `stripe_sync` | Every 15 min | stripe | Fetch incremental Stripe data for connected accounts |
| `compute_metrics` | Hourly | metrics | Aggregate raw data → financial_metric_snapshots |
| `compute_readiness` | Hourly (after metrics) | metrics | Derive readiness_score from metrics |
| `generate_recommendations` | Daily | recommendations | Run rules → recommendations table |
| `send_notification_digest` | Daily | notifications | Email users with new recs (stub in MVP) |

Job runner options: Celery + Redis, ARQ, or K8s CronJobs calling internal endpoints. Recommend **ARQ** for simplicity with FastAPI.

---

## MCP Agent Flow

```
User: "What's hurting my funding readiness?"
    → Astro calls POST /agent/chat
    → Agent module:
        1. Resolve business_id from session
        2. Call get_readiness_breakdown(business_id) → structured data
        3. Call search_knowledge("funding readiness factors") → RAG chunks
        4. Build prompt: system + RAG context + tool results + user message
        5. LLM call (OpenAI, etc.)
        6. Return response, persist to agent_messages
```

MCP server can run:
- **Same process**: FastAPI app hosts MCP; agent route invokes MCP tools internally
- **Separate process**: MCP server as subprocess/container; FastAPI calls it via stdio or HTTP

For MVP, same-process is simpler: tools are Python functions that query DB/metrics.

---

## RAG (Pinecone) Flow

**Index**: `vaultra-knowledge` (or per-env: `vaultra-knowledge-dev`)

**Metadata** (stored with each vector):
- `source` (e.g., "best-practices", "lending-criteria")
- `category` (e.g., "cash-flow", "chargebacks")
- `url` or `doc_id` (for citation)

**Knowledge base content** (what to ingest for MVP):

| Source | Category | Content |
|--------|----------|---------|
| `docs/knowledge/funding-readiness-factors.md` | lending-criteria | What lenders look for: revenue stability, chargeback ratio, payout history |
| `docs/knowledge/reducing-chargebacks.md` | chargebacks | Best practices: clear descriptors, customer communication, dispute handling |
| `docs/knowledge/revenue-stability.md` | cash-flow | How to stabilize revenue: diversification, retention, forecasting |
| `docs/knowledge/payout-timing.md` | cash-flow | Improving payout reliability: Stripe Radar, reserve management |
| `docs/knowledge/readiness-score-explained.md` | best-practices | How Vaultra's score is calculated, what each component means |

**Ingestion** (one-time or CI):
- Markdown files in `backend/docs/knowledge/` or GCS bucket
- Chunk: 512 tokens max, 50-token overlap between chunks
- Embed: OpenAI `text-embedding-3-small`
- Upsert to Pinecone with metadata `{ source, category, doc_id }`

**Query** (at agent runtime):
- User question → embed → query Pinecone (top-k=5)
- Inject chunks into LLM context with citation: `[Source: doc_id]`

---

## Deployment Layout (Kubernetes)

```
                    ┌─────────────┐
                    │   Ingress   │
                    │  (LB + TLS) │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌─────▼─────┐
    │   Astro     │ │   FastAPI   │ │ (static)  │
    │  (static)   │ │   (api)     │ │           │
    │  GCS/CDN    │ │  Deployment │ │           │
    └─────────────┘ └──────┬──────┘ └───────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼────┐
    │  Cloud SQL  │ │    Redis    │ │  Pinecone │
    │ (Postgres)  │ │  (jobs)     │ │  (SaaS)   │
    └─────────────┘ └─────────────┘ └───────────┘
```

- **FastAPI**: Single Deployment, HPA, 2–10 replicas
- **Jobs**: Same image, different entrypoint (e.g., `arq worker`) or K8s CronJob
- **Astro**: Build to static, serve via GCS + CDN or nginx sidecar

---

## Environment Configuration

| Env Var | Purpose |
|---------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis for job queue |
| `STRIPE_SECRET_KEY` | Stripe API |
| `STRIPE_WEBHOOK_SECRET` | Verify webhooks |
| `STRIPE_CONNECT_CLIENT_ID` | OAuth connect |
| `PINECONE_API_KEY` | Pinecone |
| `PINECONE_INDEX` | Index name |
| `OPENAI_API_KEY` | LLM + embeddings |
| `JWT_SECRET` | Sign JWTs |

---

## Security Notes

- Stripe webhook: verify `Stripe-Signature` before processing
- All `/api/*` (except webhooks) require `Authorization: Bearer <jwt>`
- Business scoping: every query filters by `business_id` from JWT
- No PCI: store only Stripe object IDs and aggregated amounts, never raw card data
- Secrets from GCP Secret Manager, mounted as env or K8s secrets

---

## Frontend Structure

### Astro Application Structure

```
frontend/
├── src/
│   ├── pages/              # Astro pages (routes)
│   │   ├── index.astro    # Landing/marketing page
│   │   ├── auth/
│   │   │   ├── login.astro
│   │   │   ├── signup.astro
│   │   │   └── callback.astro  # OAuth callback handler
│   │   ├── dashboard/
│   │   │   ├── index.astro           # Readiness overview
│   │   │   ├── recommendations.astro # Recommendations list
│   │   │   ├── metrics.astro         # Metrics history/charts
│   │   │   └── agent.astro           # Agent chat interface
│   │   └── onboarding/
│   │       ├── business.astro        # Business profile setup
│   │       └── stripe-connect.astro # Stripe OAuth flow
│   ├── components/         # Reusable components
│   │   ├── ScoreCard.astro           # Score display card
│   │   ├── MetricsChart.tsx           # React island: charts
│   │   ├── RecommendationList.tsx    # React island: recommendations
│   │   ├── AgentChat.tsx             # React island: chat UI
│   │   ├── BusinessSelector.tsx      # React island: business switcher (multi-business)
│   │   └── Navigation.astro
│   ├── layouts/
│   │   ├── BaseLayout.astro
│   │   └── DashboardLayout.astro
│   ├── lib/                # Utilities
│   │   ├── api.ts          # API client functions
│   │   └── auth.ts         # Auth helpers (JWT storage)
│   └── styles/
│       └── global.css
└── public/                  # Static assets
```

### Frontend Pages & Routes

| Route | Page File | Purpose | Auth Required |
|-------|-----------|---------|---------------|
| `/` | `index.astro` | Landing/marketing page | No |
| `/auth/login` | `auth/login.astro` | Login form | No |
| `/auth/signup` | `auth/signup.astro` | Signup form | No |
| `/auth/callback/google` | `auth/callback.astro` | OAuth callback handler | No |
| `/onboarding/business` | `onboarding/business.astro` | Business profile setup | Yes |
| `/onboarding/stripe-connect` | `onboarding/stripe-connect.astro` | Stripe OAuth initiation | Yes |
| `/dashboard` | `dashboard/index.astro` | Readiness overview | Yes |
| `/dashboard/recommendations` | `dashboard/recommendations.astro` | Recommendations list | Yes |
| `/dashboard/metrics` | `dashboard/metrics.astro` | Metrics history/charts | Yes |
| `/dashboard/agent` | `dashboard/agent.astro` | Agent chat interface | Yes |

### Frontend Components

**ScoreCard** (Astro):
- Props: `score` (0-100), `tier` (string), `trend?` ("improving"|"stable"|"declining")
- Displays: Large score number, tier badge with color, trend arrow

**MetricsChart** (React island):
- Props: `metrics` (array), `type` ("revenue"|"volatility"|"chargebacks"|"readiness")
- Library: Chart.js or Recharts
- Features: Time-series charts, tooltips, responsive

**RecommendationList** (React island):
- Props: `recommendations` (array), `onAction` (callback)
- Features: Filter by status/priority, sort, actions (mark done, dismiss)

**AgentChat** (React island):
- Props: `businessId` (UUID), `conversationId?` (UUID)
- Features: Message input, conversation history, loading states, error handling

**BusinessSelector** (React island):
- Props: `businesses` (array of `{ id, name }`), `currentId` (UUID), `onChange` (callback with new id)
- Features: Dropdown or list; on select, call `onChange(id)`; parent stores in localStorage and refetches data

### Frontend API Client

**Location**: `src/lib/api.ts`

Functions for all backend endpoints:
- `signup()`, `login()`, `getCurrentUser()`
- `getUserProfile()`, `createBusiness()`, `updateBusiness()`
- `getLatestMetrics()`, `getMetricHistory()`, `getReadinessScore()`
- `getRecommendations()`, `updateRecommendationStatus()`
- `chatWithAgent()`, `getConversation()`
- `initiateStripeConnect()`, `getStripeStatus()`

**Auth**: All requests include `Authorization: Bearer <jwt>` header (except signup/login)

**Base URL**: `process.env.PUBLIC_API_URL || 'http://localhost:8000/api/v1'`

### Frontend Authentication

- **JWT Storage**: `localStorage.setItem('vaultra_token', token)`
- **Protected Routes**: Check JWT on page load, redirect to `/auth/login` if missing
- **Auth Helper**: `src/lib/auth.ts` with `getToken()`, `setToken()`, `isAuthenticated()`, `getAuthHeaders()`

### Multi-Business UX

**Business selector** (required when user has 2+ businesses):
- Location: Dashboard layout header/sidebar
- Component: `<BusinessSelector />` — dropdown or list of `{ id, name }` from `GET /users/me`
- On change: Store `business_id` in `localStorage.setItem('vaultra_current_business_id', id)` and reload dashboard data
- Default: If one business, auto-select. If multiple and none stored, show selector; require selection before showing metrics/recs/agent

**URL pattern** (optional but recommended for deep-linking):
- `/dashboard?business_id=<uuid>` or `/dashboard/<business_id>/` — pass `business_id` to all API calls on that page

---

## Backend Module Implementation Details

### Module Structure Pattern

Each module follows this structure:

```
app/{module}/
├── __init__.py
├── models.py          # SQLAlchemy ORM models (if needed)
├── schemas.py         # Pydantic request/response models
├── service.py         # Business logic implementation
└── router.py          # FastAPI route handlers (optional, or in api/v1/)
```

### Service Interface Pattern

Each module exposes a `Service` class:

```python
class {Module}Service:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def {operation}(self, ...) -> {ReturnType}:
        """Business logic implementation."""
```

### Error Handling

- **Validation errors**: Return `400 Bad Request` with error details
- **Authentication errors**: Return `401 Unauthorized`
- **Authorization errors**: Return `403 Forbidden`
- **Not found**: Return `404 Not Found`
- **Server errors**: Return `500 Internal Server Error`, log details

---

## Infrastructure Specifications

### Docker

**Backend Dockerfile**:
- Base: `python:3.11-slim`
- Install: System deps (gcc, postgresql-client), Python deps from `requirements.txt`
- Copy: `app/`, `alembic/`, `alembic.ini`
- Expose: Port 8000
- CMD: `uvicorn app.main:app --host 0.0.0.0 --port 8000`

**docker-compose.yml** (local dev):
- Services: `postgres` (port 5432), `redis` (port 6379), `backend` (port 8000)
- Volumes: Postgres data persistence
- Health checks: For postgres and redis

### Kubernetes (GKE)

**Namespace**: `vaultra`

**Backend Deployment**:
- Replicas: 2 (min), HPA: 2-10 replicas
- Resources: Requests 256Mi/250m, Limits 512Mi/500m
- Health checks: `/health` endpoint
- Environment: All secrets from K8s secrets (GCP Secret Manager)

**Frontend Deployment**:
- Static files: Served via nginx sidecar or GCS + CDN
- Replicas: 2

**Ingress**:
- TLS: Managed certificate
- Routes: `api.vaultra.com` → backend, `vaultra.com` → frontend

**CronJobs**:
- `compute-metrics`: Hourly (`0 * * * *`)
- `generate-recommendations`: Daily (`0 2 * * *`)

---

## Document Links

| Document | Purpose |
|----------|---------|
| [SPEC.md](./SPEC.md) | Product scope |
| [TECH_STACK.md](./TECH_STACK.md) | Technology choices |
| **ARCHITECTURE.md** | This document: services, APIs, deployment, frontend structure |
| [DATA_MODEL.md](./DATA_MODEL.md) | Schemas, tables |
