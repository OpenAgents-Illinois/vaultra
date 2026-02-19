# Vaultra — Implementation Specification

> Detailed implementation-level specifications for backend modules, frontend components, and infrastructure setup.

## Backend Module Implementations

### Module Structure

Each module in `backend/app/{module}/` follows this pattern:

```
{module}/
├── __init__.py
├── models.py          # SQLAlchemy ORM models (from DATA_MODEL.md)
├── schemas.py         # Pydantic request/response models
├── service.py         # Business logic (implements interface from specs)
└── (optional) router.py  # FastAPI routes (or in api/v1/{module}.py)
```

### Service Interface Pattern

All services follow this interface pattern:

```python
from sqlalchemy.ext.asyncio import AsyncSession

class {Module}Service:
    """{Module} service implementation.
    
    See app/specs/{module}.md for detailed specification.
    """
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def {operation}(self, ...) -> {ReturnType}:
        """{Description}.
        
        See app/specs/{module}.md for specification.
        """
        # Implementation
```

### Error Handling Standards

- **Validation errors** (400): Use Pydantic validation, return clear error messages
- **Authentication errors** (401): "Invalid authentication credentials"
- **Authorization errors** (403): "You don't have permission to access this resource"
- **Not found** (404): "Resource not found"
- **Conflict** (409): "Resource already exists" (e.g., duplicate email)
- **Server errors** (500): Log full error, return generic message to client

---

## Frontend Implementation

### Astro Setup

**Configuration** (`astro.config.mjs`):
- Integrations: `@astrojs/react` (for islands), `@astrojs/tailwind` (for styling)
- Output: `static` (pre-render all pages)
- Proxy: `/api` → `http://localhost:8000/api/v1` (dev only)

**Package.json dependencies**:
- `astro`: Core framework
- `@astrojs/react`: React islands support
- `@astrojs/tailwind`: Tailwind CSS
- `react`, `react-dom`: For interactive components
- `chart.js` or `recharts`: For metrics charts

### Component Implementation

**ScoreCard** (`src/components/ScoreCard.astro`):
- Accepts: `score`, `tier`, `trend?`
- Renders: Large score display, colored tier badge, trend indicator
- Styling: Tailwind classes

**MetricsChart** (`src/components/MetricsChart.tsx`):
- React component (island)
- Props: `metrics` array, `type` string
- Uses Chart.js or Recharts
- Fetches data via `getMetricHistory()` from `lib/api.ts`

**RecommendationList** (`src/components/RecommendationList.tsx`):
- React component (island)
- Props: `recommendations` array, `onAction` callback
- State: Filters (status, priority), sorting
- Actions: Calls `updateRecommendationStatus()` API

**AgentChat** (`src/components/AgentChat.tsx`):
- React component (island)
- State: Messages array, input value, loading state
- Effects: Fetch conversation history on mount
- Handlers: `handleSend()` calls `chatWithAgent()` API

**DashboardGuard** (`src/components/DashboardGuard.tsx`):
- React component (island)
- Props: `children`
- On mount: Call `getToken()`; if null, `window.location.href = '/auth/login'`; else render children
- Used to wrap protected dashboard pages when using static output

**BusinessSelector** (`src/components/BusinessSelector.tsx`):
- Props: `businesses` (array of `{ id, name }`), `currentId` (UUID), `onChange` (callback)
- Renders dropdown; on select, call `onChange(id)`; parent stores in localStorage and refetches

### API Client Implementation

**File**: `src/lib/api.ts`

```typescript
const API_BASE = import.meta.env.PUBLIC_API_URL || 'http://localhost:8000/api/v1';

async function apiRequest(endpoint: string, options?: RequestInit) {
  const token = getToken();
  const headers = {
    'Content-Type': 'application/json',
    ...(token && { Authorization: `Bearer ${token}` }),
    ...options?.headers,
  };
  
  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers,
  });
  
  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }
  
  return response.json();
}

// Auth
export async function signup(email: string, password: string, name: string) {
  return apiRequest('/auth/signup', {
    method: 'POST',
    body: JSON.stringify({ email, password, name }),
  });
}

// ... (all other API functions)
```

### Authentication Flow

**File**: `src/lib/auth.ts`

```typescript
const TOKEN_KEY = 'vaultra_token';

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function removeToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export function isAuthenticated(): boolean {
  return getToken() !== null;
}

export function getAuthHeaders(): HeadersInit {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}
```

**Protected Route Pattern** (in Astro pages):

For **SSR** (`output: 'server'` in astro.config):
```astro
---
import { getToken } from '../lib/auth';
// getToken() must read from cookie or request headers for SSR; for cookie-based auth, pass cookie to getToken
const token = getToken();
if (!token) {
  return Astro.redirect('/auth/login');
}
---
```

For **static/SSG** (`output: 'static'`): JWT is in localStorage (client-only). Use a client-side guard:
```astro
---
import DashboardGuard from '../components/DashboardGuard';
---
<DashboardGuard>
  <!-- Dashboard content -->
</DashboardGuard>
```
`DashboardGuard` (React island): On mount, check `getToken()`; if null, `window.location.href = '/auth/login'`; else render children.

---

## Database Models (SQLAlchemy)

### Model Pattern

```python
from sqlalchemy import Column, String, DateTime, UUID
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.sql import func
from app.shared.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(PG_UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid())
    email = Column(String(255), unique=True, nullable=False)
    hashed_password = Column(String(255), nullable=True)
    name = Column(String(255))
    avatar_url = Column(String(512))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
```

See `docs/DATA_MODEL.md` for all table schemas.

---

## Infrastructure Implementation

### Docker Compose (Local Dev)

**Services**:
- `postgres`: PostgreSQL 15, port 5432, volume for persistence
- `redis`: Redis 7, port 6379
- `backend`: FastAPI app, port 8000, depends on postgres/redis

**Environment**: `.env` file loaded by docker-compose

### Kubernetes Manifests

**Directory**: `infra/k8s/`

**Files**:
- `namespace.yaml`: `vaultra` namespace
- `backend/deployment.yaml`: FastAPI deployment, 2 replicas min
- `backend/service.yaml`: ClusterIP service
- `backend/hpa.yaml`: HorizontalPodAutoscaler (2-10 replicas)
- `frontend/deployment.yaml`: nginx serving static files
- `frontend/service.yaml`: ClusterIP service
- `ingress.yaml`: Ingress with TLS
- `secrets.yaml.example`: Example secrets (use GCP Secret Manager in prod)
- `jobs/cronjob-metrics.yaml`: Hourly metrics computation
- `jobs/cronjob-recommendations.yaml`: Daily recommendations generation

**Secrets Management**:
- Development: K8s secrets from `secrets.yaml`
- Production: GCP Secret Manager CSI driver or external-secrets operator

---

## Testing Strategy

### Backend Tests

**Structure**: `backend/tests/`

- **Unit tests**: Test service logic in isolation (mock DB)
- **Integration tests**: Test API endpoints with test DB
- **Test database**: Separate test DB, reset between tests

**Framework**: `pytest`, `pytest-asyncio`, `httpx` for API testing

### Frontend Tests

**Structure**: `frontend/tests/`

- **Component tests**: Test React islands (Vitest + React Testing Library)
- **E2E tests**: Test critical flows (Playwright)

---

## CI/CD Pipeline

### GitHub Actions Workflows

**`.github/workflows/ci.yml`**:
- On push/PR: Run backend tests, frontend tests, linting
- On merge to main: Build Docker images, push to GCR, deploy to staging

**`.github/workflows/deploy.yml`**:
- On tag: Build production images, deploy to production GKE

---

## Document Links

| Document | Purpose |
|----------|---------|
| [SPEC.md](./SPEC.md) | Product scope, user flows |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Services, APIs, frontend structure |
| [DATA_MODEL.md](./DATA_MODEL.md) | Database schemas |
| [TECH_STACK.md](./TECH_STACK.md) | Technology choices |
| **IMPLEMENTATION_SPEC.md** | This document: implementation details |
