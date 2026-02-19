# Vaultra — Product Specification

> AI agent that small business owners "hire" to proactively manage creditworthiness and funding readiness.

## Vision

Vaultra doesn't wait for a user to ask for a loan. It continuously optimizes their financial profile so they're *instantly underwritable* when opportunity arises.

## Tech Stack Summary

| Layer | Technology |
|-------|------------|
| Frontend | Astro |
| Backend | Python / FastAPI |
| AI Agent | MCP + RAG (Pinecone) |
| Payments | Stripe API |
| Database | PostgreSQL |

See [TECH_STACK.md](./TECH_STACK.md) for full rationale and data flow.

---

## MVP Scope

### In Scope

- **Onboarding**: Business profile, connect Stripe (OAuth)
- **Stripe ingestion**: Revenue, payouts, disputes, chargebacks, subscriptions (basic)
- **Funding readiness score**: 0–100 + tier (Not ready → Funding-ready → Highly attractive)
- **Proactive recommendations**: Rules-based engine, daily jobs, in-app + email
- **AI agent**: Natural language Q&A over metrics + RAG knowledge base (MCP)
- **Dashboard**: Astro UI with score, metrics, recommendations, agent chat
- **Infra**: Docker, Kubernetes (GKE), PostgreSQL (Cloud SQL)

### Out of Scope (MVP)

- Loan origination, KYC/KYB
- Investment/trading advice
- Direct bank connections (beyond Stripe)
- Full accounting integrations

---

## Key User Flows

1. **Onboard & Connect** — Sign up → Business profile → Connect Stripe → Land on dashboard
2. **Proactive loop** — Jobs run → Metrics + score updated → Recommendations generated → Notifications sent
3. **Ask agent** — "What's hurting my funding readiness?" → Agent uses MCP tools + RAG to answer

---

## Non-Functional Requirements

- **Scalability**: 1–10k SMBs (path to 100k)
- **Reliability**: Retryable jobs, DLQ for webhooks
- **Security**: Secrets in GCP Secret Manager, no PCI storage, TLS everywhere

---

## Spec Documents

> 📖 **Start here**: See [SPECIFICATION_INDEX.md](./SPECIFICATION_INDEX.md) for a complete guide to all specifications.

| Document | Purpose |
|----------|---------|
| [SPECIFICATION_INDEX.md](./SPECIFICATION_INDEX.md) | **Complete guide to all specs** - roadmap for implementation |
| [BACKGROUND_AND_VISION.md](./BACKGROUND_AND_VISION.md) | Business problems, what the agent solves, why it matters |
| [SPEC.md](./SPEC.md) | Product scope, flows, NFRs |
| [TECH_STACK.md](./TECH_STACK.md) | Technology choices and data flow |
| [LLM_SPEC.md](./LLM_SPEC.md) | LLM provider abstraction (OpenAI + Ollama) |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Services, APIs, deployment, frontend structure |
| [DATA_MODEL.md](./DATA_MODEL.md) | Database schemas, tables, migrations |
| [BACKEND_SERVICES_SPEC.md](./BACKEND_SERVICES_SPEC.md) | Backend service interfaces and business logic |
| [IMPLEMENTATION_SPEC.md](./IMPLEMENTATION_SPEC.md) | Implementation details: module structure, components, infrastructure |
| [API_SCHEMAS.md](./API_SCHEMAS.md) | Explicit request/response JSON schemas for all endpoints |
| [SCAFFOLDING_GUIDE.md](./SCAFFOLDING_GUIDE.md) | Step-by-step scaffolding instructions for coding agents |
