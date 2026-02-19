# Vaultura — Architecture Specification

> Service boundaries, API contracts, and deployment layout. Spec-driven; implementation follows.

## Architecture Style

**Modular monolith** for MVP: single FastAPI app with clear module boundaries, deployable as one service. Path to split into microservices exists if scale demands it.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           VAULTURA APP                                   │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────────┤
│   auth      │   users     │   stripe    │  metrics    │   agent         │
│   module    │   module    │   module    │  module     │   module        │
├─────────────┴─────────────┴─────────────┴─────────────┴─────────────────┤
│                     Shared: DB, Redis, Pinecone, Stripe SDK              │
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

| Method | Path | Module | Description |
|--------|------|--------|-------------|
| POST | /auth/signup | auth | Create account |
| POST | /auth/login | auth | Login, return JWT |
| GET | /auth/callback/google | auth | OAuth callback |
| GET | /auth/me | auth | Current user (requires auth) |
| | | | |
| GET | /users/me | users | Current user + businesses |
| PATCH | /users/me | users | Update profile |
| POST | /users/businesses | users | Create business |
| PATCH | /users/businesses/{id} | users | Update business |
| | | | |
| GET | /integrations/stripe/connect | stripe | Initiate Stripe OAuth |
| GET | /integrations/stripe/callback | stripe | Stripe OAuth callback |
| GET | /integrations/stripe/status | stripe | Connection status |
| POST | /webhooks/stripe | stripe | Stripe webhook receiver (no auth) |
| | | | |
| GET | /metrics | metrics | Latest metrics for business |
| GET | /metrics/history | metrics | Time-series metrics |
| GET | /readiness | metrics | Current score + tier |
| GET | /readiness/history | metrics | Score history |
| | | | |
| GET | /recommendations | recommendations | List for business |
| PATCH | /recommendations/{id} | recommendations | Update status (dismiss/accept) |
| | | | |
| POST | /agent/chat | agent | Send message, get reply (streaming optional) |
| GET | /agent/conversations/{id} | agent | Conversation history |

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

**Index**: `vaultura-knowledge` (or per-env: `vaultura-knowledge-dev`)

**Metadata** (stored with each vector):
- `source` (e.g., "best-practices", "lending-criteria")
- `category` (e.g., "cash-flow", "chargebacks")
- `url` or `doc_id` (for citation)

**Ingestion** (one-time or CI):
- Markdown/docs in repo or GCS
- Chunk (e.g., 512 tokens, overlap)
- Embed via OpenAI `text-embedding-3-small`
- Upsert to Pinecone

**Query** (at agent runtime):
- User question → embed → query Pinecone (top-k=5)
- Inject chunks into LLM context

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
    ┌──────▼──────┐ ┌──────▼──────┐ ┌─────▼─────┐
    │  Cloud SQL  │ │    Redis    │ │  Pinecone │
    │ (Postgres)  │ │  (jobs)    │ │  (SaaS)   │
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

## Document Links

| Document | Purpose |
|----------|---------|
| [SPEC.md](./SPEC.md) | Product scope |
| [TECH_STACK.md](./TECH_STACK.md) | Technology choices |
| **ARCHITECTURE.md** | This document: services, APIs, deployment |
| [DATA_MODEL.md](./DATA_MODEL.md) | Schemas, tables |
