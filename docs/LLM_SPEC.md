# Vaultra — LLM Provider Specification

> How Vaultra uses OpenAI and Ollama behind a single interface.

---

## Goals

- Decouple Vaultra's agent logic from any single LLM vendor.
- Support **local development** with Ollama and **cloud production** with OpenAI.
- Keep orchestration simple in v1 (no LangChain/LangGraph), while leaving room to add them later if flows become complex.

---

## Abstraction: `LLMProvider`

The agent service talks to an abstract `LLMProvider`, not directly to OpenAI/Ollama.

```text
Agent (MCP) → LLMProvider (interface) → [OpenAIProvider | OllamaProvider]
```

### Interface (conceptual)

- `generate(request) -> response`

Where `request` contains:
- `messages`: ordered list of `{ role: "system" | "user" | "assistant" | "tool", content: str }`
- `tools` (optional): tool/function definitions (for MCP/tool-calling capable models)
- `tool_choice` (optional): how to route tool calls
- `temperature`, `max_tokens`, etc.

And `response` contains:
- `content`: final assistant message (string)
- `tool_calls` (optional): structured tool calls if the model decided to use tools

We will mirror the OpenAI Chat Completions shape where convenient, but keep the interface narrow and under our control.

---

## Implementations

### OpenAIProvider

- **When used**: `LLM_PROVIDER=openai`
- **Config**:
  - `OPENAI_API_KEY`
  - `OPENAI_MODEL` (e.g., `gpt-4.1` or similar)
- **Responsibilities**:
  - Format `messages` + optional `tools` into OpenAI Chat Completions requests.
  - Handle rate limits and retries.
  - Map OpenAI responses into the generic `LLMProvider` response shape.

### OllamaProvider

- **When used**: `LLM_PROVIDER=ollama`
- **Config**:
  - `OLLAMA_BASE_URL` (default `http://localhost:11434`)
  - `OLLAMA_MODEL` (e.g., `llama3.1:8b`)
- **Responsibilities**:
  - Call Ollama's HTTP API (e.g., `/api/chat`) with the same `messages` structure.
  - Optionally emulate tool-calling behavior in-app if/when needed.
  - Return results in the same `LLMProvider` response shape.

Note: Ollama is primarily used for **local dev** and **self-hosted** deployments; production cloud may prefer managed APIs (OpenAI) unless the team explicitly chooses to operate Ollama on GKE.

---

## Orchestration

- **MCP + simple Python orchestration**:
  - The agent flow (tools → RAG → prompt building → LLM) is implemented directly in Python/FastAPI.
  - MCP tools encapsulate data access (metrics, recommendations, knowledge search).
  - We do not introduce LangChain or LangGraph in v1 to keep:
    - Dependencies light.
    - Control and observability high.

- **Future option**:
  - If agent flows become more complex (multi-step, conditional, parallel tools), we may:
    - Introduce **LangGraph** as an orchestration layer on top of `LLMProvider`, or
    - Keep a custom lightweight orchestrator tailored to Vaultra's needs.

---

## Environment Variables (LLM-related)

| Variable | Purpose |
|---------|---------|
| `LLM_PROVIDER` | `openai` \| `ollama` (selects backend) |
| `OPENAI_API_KEY` | OpenAI auth token |
| `OPENAI_MODEL` | Model name for OpenAI backend |
| `OLLAMA_BASE_URL` | Ollama HTTP endpoint (dev: `http://localhost:11434`) |
| `OLLAMA_MODEL` | Model name loaded in Ollama |

---

## Document Links

| Document | Purpose |
|----------|---------|
| [SPEC.md](./SPEC.md) | Product scope |
| [TECH_STACK.md](./TECH_STACK.md) | Technology choices (incl. LLM section) |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Services, APIs, deployment, frontend structure |
| [BACKEND_SERVICES_SPEC.md](./BACKEND_SERVICES_SPEC.md) | Backend service interfaces and business logic |
| [DATA_MODEL.md](./DATA_MODEL.md) | Database schemas, tables, migrations |

