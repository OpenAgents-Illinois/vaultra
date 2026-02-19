# Vaultra

> AI agent that small business owners "hire" to proactively manage creditworthiness and funding readiness.

## Overview

Vaultra doesn't wait for a user to ask for a loan. It continuously optimizes their financial profile so they're *instantly underwritable* when opportunity arises.

See [docs/BACKGROUND_AND_VISION.md](./docs/BACKGROUND_AND_VISION.md) for the full vision and business problems this solves.

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Astro |
| **Backend** | Python / FastAPI |
| **AI Agent** | MCP + RAG (Pinecone) |
| **Payments** | Stripe API |
| **Database** | PostgreSQL |
| **Infrastructure** | Docker, Kubernetes (GKE), Google Cloud |

See [docs/TECH_STACK.md](./docs/TECH_STACK.md) for full rationale.

## Project Structure

```
vaultra/
└── docs/              # Specifications (spec-driven development)
    ├── SPEC.md       # Product scope, flows
    ├── ARCHITECTURE.md  # Backend services, APIs, deployment
    ├── FRONTEND_SPEC.md # Frontend pages, components, routes
    ├── DATA_MODEL.md    # Database schemas
    ├── TECH_STACK.md    # Technology choices
    └── LLM_SPEC.md      # LLM provider abstraction
```

**Implementation directories** (`backend/`, `frontend/`, `infra/`) will be created following the specifications.

## Documentation

All specifications are in `docs/`:

- **[BACKGROUND_AND_VISION.md](./docs/BACKGROUND_AND_VISION.md)** — Business problems and vision
- **[SPEC.md](./docs/SPEC.md)** — Product scope and MVP
- **[ARCHITECTURE.md](./docs/ARCHITECTURE.md)** — Backend service boundaries, APIs, deployment
- **[FRONTEND_SPEC.md](./docs/FRONTEND_SPEC.md)** — Frontend pages, components, routes, API integration
- **[DATA_MODEL.md](./docs/DATA_MODEL.md)** — Database schemas
- **[TECH_STACK.md](./docs/TECH_STACK.md)** — Technology choices
- **[LLM_SPEC.md](./docs/LLM_SPEC.md)** — LLM provider abstraction

## Development Workflow

This project follows **spec-driven development**:

1. **Specs first**: All features are specified in `docs/` before implementation
2. **Implementation**: Code follows the specifications
3. **Documentation**: Code references spec documents

## License

[To be determined]
