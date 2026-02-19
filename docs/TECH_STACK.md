# Vaultura — Tech Stack Specification

> Spec-driven development: tech choices are locked before implementation.

## Overview

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Frontend** | Astro | Marketing site, dashboard UI, static + islands |
| **Backend API** | Python / FastAPI | REST API, auth, business logic, job orchestration |
| **AI Agent** | MCP (Model Context Protocol) | Structured tooling and context for LLM |
| **RAG** | Pinecone | Vector store for financial knowledge, policies, recommendations |
| **Payments & Revenue** | Stripe API | Connect, revenue data, payment metrics |
| **Primary Database** | PostgreSQL | Users, businesses, metrics, scores, recommendations |

---

## Stack Details

### Frontend: Astro

- **Why Astro**: Fast, content-focused, minimal JS by default. Excellent for:
  - Marketing/landing pages (pre-rendered, SEO-friendly)
  - Dashboard with islands of interactivity (e.g., charts, agent chat) without full SPA overhead
- **Use cases**: Auth pages, business onboarding, funding-readiness dashboard, agent chat UI
- **Pattern**: Astro pages + framework islands (React or Vue for interactive components if needed)

---

### Backend: Python / FastAPI

- **Why FastAPI**: Async, type hints, OpenAPI auto-gen, great for APIs and background jobs
- **Use cases**:
  - REST API for frontend
  - Stripe webhook handlers
  - Cron-style background jobs (metric computation, recommendation engine)
  - Internal services consumed by MCP agent
- **Conventions**: Pydantic models, async SQLAlchemy or SQLModel, dependency injection

---

### AI Agent: MCP (Model Context Protocol)

- **Why MCP**: Standard protocol for connecting LLMs to tools and data sources. Enables:
  - Structured tool definitions (fetch metrics, list recommendations, run scoring)
  - Consistent context injection (RAG chunks, user profile, current score)
  - Swappable LLM providers without rewriting agent logic
- **Use cases**:
  - "What's hurting my funding readiness?" → tool: `get_readiness_breakdown`
  - "What should I do this week?" → tool: `get_top_recommendations`
  - Natural language over structured fin data + RAG knowledge

---

### RAG: Pinecone

- **Why Pinecone**: Managed vector DB, low ops, good fit for semantic search
- **Use cases**:
  - Financial best-practices knowledge base (e.g., "how to improve DSO")
  - Lending criteria / underwriting policy docs
  - Recommendation templates and explanations
- **Flow**: Ingest docs → embed (e.g., OpenAI, Cohere) → upsert to Pinecone → query at agent runtime for context

---

### Payments & Revenue: Stripe API

- **Integrations**:
  - **Stripe Connect** (or OAuth) for account linking
  - Charges, payouts, disputes, refunds for revenue and risk metrics
  - Subscriptions for MRR/churn (if applicable)
- **Data used**: Revenue trends, volatility, chargeback ratio, payout reliability

---

### Database: PostgreSQL

- **Why PostgreSQL**:
  - Mature, reliable, great for structured financial data
  - Strong support for JSON when needed (e.g., raw event metadata)
  - Time-series–friendly (metric snapshots, scores over time)
  - Excellent FastAPI ecosystem (SQLAlchemy, Alembic, asyncpg)
  - Cloud SQL on GCP for production
- **Responsibilities**:
  - Users, businesses, integrations
  - Metric snapshots, readiness scores
  - Recommendations, agent conversations
  - Job state, webhook event log

---

## Infrastructure (from spec)

| Component | Technology |
|-----------|------------|
| Containerization | Docker |
| Orchestration | Kubernetes (GKE on Google Cloud) |
| Managed DB | Cloud SQL (PostgreSQL) |
| Secrets | GCP Secret Manager / K8s secrets |
| Queues / Events | Pub/Sub or Redis (for jobs, Stripe webhooks) |
| Object storage | GCS (reports, exports) |

---

## Data Flow (High Level)

```
Stripe API → FastAPI webhooks → PostgreSQL (raw/agg)
                    ↓
         Background jobs (FastAPI/Celery/ARQ)
                    ↓
         Metrics + Scores + Recommendations
                    ↓
    Pinecone (RAG) ←→ MCP Agent ←→ User query
                    ↓
         Astro dashboard / agent chat
```

---

## Document Hierarchy

1. **SPEC.md** — Product spec, user flows, scope
2. **TECH_STACK.md** — This document: technology choices
3. **ARCHITECTURE.md** — Service boundaries, API contracts, deployment
4. **DATA_MODEL.md** — Schemas, tables, migrations
