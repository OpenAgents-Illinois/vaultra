# Vaultra — Specification Index

> Complete guide to all specification documents. Use this as a roadmap for implementation.

**Coding agents**: Start with [SCAFFOLDING_GUIDE.md](./SCAFFOLDING_GUIDE.md) and follow phases 1–4 to scaffold the application. Use this index to find detailed specs when implementing each part.

## Specification Overview

This directory contains comprehensive specifications for building Vaultra, a fintech AI agent for proactive creditworthiness and funding readiness management. All specifications follow a **spec-driven development** approach: define everything before implementation.

---

## Core Specifications

### 1. [BACKGROUND_AND_VISION.md](./BACKGROUND_AND_VISION.md)
**Purpose**: Business context and product vision

**Contents**:
- The business problem Vaultra solves
- Why small businesses struggle with funding readiness
- Key features and benefits
- What Vaultra is and is not

**Use when**: Understanding the "why" behind the product

---

### 2. [SPEC.md](./SPEC.md)
**Purpose**: Product scope and high-level requirements

**Contents**:
- Product vision statement
- MVP scope (in-scope vs out-of-scope)
- Key user flows
- Non-functional requirements (scalability, reliability, security)

**Use when**: Defining what features to build in MVP

---

### 3. [TECH_STACK.md](./TECH_STACK.md)
**Purpose**: Technology choices and rationale

**Contents**:
- Frontend: Astro
- Backend: Python / FastAPI
- AI Agent: MCP (Model Context Protocol)
- RAG: Pinecone
- LLM: OpenAI (production) + Ollama (local dev)
- Payments: Stripe API
- Database: PostgreSQL
- Infrastructure: Docker, Kubernetes (GKE), Google Cloud

**Use when**: Making technology decisions or understanding why each tool was chosen

---

### 4. [LLM_SPEC.md](./LLM_SPEC.md)
**Purpose**: LLM provider abstraction and configuration

**Contents**:
- `LLMProvider` interface abstraction
- OpenAI provider implementation
- Ollama provider implementation (for local dev)
- Environment variables
- Orchestration strategy (no LangChain/LangGraph in v1)

**Use when**: Implementing the AI agent or switching LLM providers

---

## Architecture & Design Specifications

### 5. [ARCHITECTURE.md](./ARCHITECTURE.md)
**Purpose**: System architecture, API contracts, and frontend structure

**Contents**:
- Architecture style (modular monolith)
- Module boundaries and responsibilities
- **Complete REST API specification** (all endpoints with request/response formats)
- MCP tools (internal agent tools)
- Stripe integration flow
- Background jobs schedule
- MCP agent flow
- RAG (Pinecone) flow
- Kubernetes deployment layout
- **Frontend structure** (Astro pages, components, routes)
- Environment configuration
- Security notes

**Use when**: 
- Implementing API endpoints
- Setting up frontend pages and components
- Understanding data flows
- Planning deployment

---

### 6. [DATA_MODEL.md](./DATA_MODEL.md)
**Purpose**: Database schemas and relationships

**Contents**:
- Entity relationship diagram
- Complete table schemas:
  - `users`
  - `businesses`
  - `user_business_memberships`
  - `integration_accounts`
  - `stripe_events`
  - `financial_metric_snapshots`
  - `readiness_scores`
  - `recommendations`
  - `agent_conversations`
  - `agent_messages`
- Enums and constraints
- Migration strategy (Alembic)
- Sample queries

**Use when**: 
- Creating database migrations
- Implementing ORM models
- Writing queries

---

### 7. [BACKEND_SERVICES_SPEC.md](./BACKEND_SERVICES_SPEC.md)
**Purpose**: Backend service interfaces and business logic

**Contents**:
- **Auth Service**: Signup, login, OAuth, JWT
- **Users Service**: User profile, business CRUD
- **Stripe Service**: OAuth connect, webhooks, data sync
- **Metrics Service**: Compute metrics, readiness score calculation
- **Recommendations Service**: Rules engine, recommendation generation
- **Agent Service**: Chat flow, MCP tools, RAG integration
- **Jobs Service**: Background job specifications
- Error handling standards

**Use when**: 
- Implementing backend service classes
- Understanding business logic requirements
- Writing service tests

---

### 8. [API_SCHEMAS.md](./API_SCHEMAS.md)
**Purpose**: Explicit request/response JSON schemas

**Contents**:
- Full JSON request bodies for each endpoint
- Full JSON response bodies with example values
- Error response format
- Validation rules

**Use when**: Implementing Pydantic models, OpenAPI, or frontend TypeScript types

---

### 9. [IMPLEMENTATION_SPEC.md](./IMPLEMENTATION_SPEC.md)
**Purpose**: Implementation-level details and patterns

**Contents**:
- **Backend module structure** (file organization pattern)
- **Service interface pattern** (dependency injection)
- **Frontend implementation**:
  - Astro setup and configuration
  - Component specifications (ScoreCard, MetricsChart, RecommendationList, AgentChat)
  - API client implementation (`src/lib/api.ts`)
  - Authentication flow (`src/lib/auth.ts`)
- **Database models** (SQLAlchemy patterns)
- **Infrastructure**:
  - Docker Compose (local dev)
  - Kubernetes manifests structure
  - Secrets management
- Testing strategy
- CI/CD pipeline

**Use when**: 
- Scaffolding new modules
- Implementing frontend components
- Setting up infrastructure
- Writing tests

---

### 10. [SCAFFOLDING_GUIDE.md](./SCAFFOLDING_GUIDE.md)
**Purpose**: Step-by-step scaffolding instructions for coding agents

**Contents**:
- Phase 1: Project structure
- Phase 2: Backend scaffolding (deps, config, DB, models, migrations, each module)
- Phase 3: Frontend scaffolding (Astro, lib, layouts, components, pages)
- Phase 4: Docker & local dev
- Phase 5: RAG knowledge base
- Phase 6: Background jobs
- Validation checklist

**Use when**: Scaffolding the application from scratch; follow phases in order

---

## Specification Coverage Checklist

### ✅ Product & Vision
- [x] Business problem and vision
- [x] MVP scope
- [x] User flows
- [x] Non-functional requirements

### ✅ Technology Stack
- [x] Frontend framework (Astro)
- [x] Backend framework (FastAPI)
- [x] AI/LLM stack (MCP, RAG, OpenAI/Ollama)
- [x] Database (PostgreSQL)
- [x] Infrastructure (Docker, Kubernetes, GCP)

### ✅ Architecture
- [x] Module boundaries
- [x] API endpoints (complete with request/response formats)
- [x] Frontend structure (pages, components, routes)
- [x] Data flows
- [x] Deployment layout

### ✅ Backend Implementation
- [x] Service interfaces
- [x] Business logic specifications
- [x] Error handling standards
- [x] Module structure patterns

### ✅ Frontend Implementation
- [x] Page structure and routes
- [x] Component specifications
- [x] API client implementation
- [x] Authentication flow

### ✅ Database
- [x] Complete schema definitions
- [x] Relationships
- [x] Migration strategy

### ✅ Infrastructure
- [x] Docker setup
- [x] Kubernetes manifests structure
- [x] Environment configuration
- [x] Secrets management

### ✅ Testing & CI/CD
- [x] Testing strategy
- [x] CI/CD pipeline structure

---

## Implementation Order

When starting implementation, follow this order:

1. **Database**: Set up PostgreSQL, create migrations from `DATA_MODEL.md`
2. **Backend Core**: Implement service modules from `BACKEND_SERVICES_SPEC.md`
3. **API Layer**: Implement FastAPI routes from `ARCHITECTURE.md`
4. **Frontend Setup**: Initialize Astro project, set up structure from `IMPLEMENTATION_SPEC.md`
5. **Frontend Pages**: Implement pages and components from `ARCHITECTURE.md` frontend section
6. **AI Agent**: Implement agent service and MCP tools from `BACKEND_SERVICES_SPEC.md` and `LLM_SPEC.md`
7. **Background Jobs**: Implement jobs from `BACKEND_SERVICES_SPEC.md`
8. **Infrastructure**: Set up Docker, Kubernetes from `IMPLEMENTATION_SPEC.md`

---

## Document Dependencies

```
BACKGROUND_AND_VISION.md (foundation)
    ↓
SPEC.md (product scope)
    ↓
TECH_STACK.md (technology choices)
    ↓
┌─────────────────┬──────────────────┬─────────────────┐
│                 │                  │                 │
ARCHITECTURE.md   DATA_MODEL.md      LLM_SPEC.md
(APIs, structure) (schemas)          (LLM abstraction)
    │                  │                  │
    └──────────────────┼──────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
BACKEND_SERVICES_SPEC.md    IMPLEMENTATION_SPEC.md
(service logic)             (implementation patterns)
```

---

## Quick Reference

**Need to implement...** → **Read this spec:**

- API endpoint → `ARCHITECTURE.md` (API Surface section), `API_SCHEMAS.md` (exact JSON shapes)
- Database table → `DATA_MODEL.md`
- Backend service → `BACKEND_SERVICES_SPEC.md`
- Frontend page → `ARCHITECTURE.md` (Frontend Structure section)
- Frontend component → `IMPLEMENTATION_SPEC.md` (Frontend Implementation section)
- LLM integration → `LLM_SPEC.md`
- Background job → `BACKEND_SERVICES_SPEC.md` (Jobs Service section)
- Docker/K8s setup → `IMPLEMENTATION_SPEC.md` (Infrastructure section)
- Scaffolding from scratch → `SCAFFOLDING_GUIDE.md` (follow phases in order)
- Error handling → `BACKEND_SERVICES_SPEC.md` (Error Handling Standards section)

---

## Questions?

If a specification is unclear or missing details:
1. Check the relevant spec document first
2. Cross-reference with related specs
3. Update the spec document with clarifications
4. Follow spec-driven development: update specs before changing implementation
