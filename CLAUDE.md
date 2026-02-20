# CLAUDE.md

> **Shared project standards for Claude Code and Cursor.** Canonical source; both tools use this file.

## Project Standards

- **Language:** Use the primary language and version detected in the workspace.
- **Issues:** Use `.github/prompts/ISSUE_PROMPT.md` for issue creation and task documentation.
- **Commits:** Use `.github/prompts/COMMIT_PROMPT.md` for commit message formatting.
- **Development:** Spec-driven; implementation follows specs in `docs/` (see Development & Scaffolding below).

## Issue Tracking

When drafting or creating a GitHub issue:

1. **Context:** Identify primary language and framework (e.g. Python/FastAPI, Astro/React).
2. **Read:** `.github/prompts/ISSUE_PROMPT.md` for structure and prefixes ([BUG], [FEAT], [ENH], etc.).
3. **Implementation:** In "Proposed Implementation," use this project's language and practices.
4. **Follow:** Prefix and format from ISSUE_PROMPT.md.

## Development & Scaffolding

**Spec-driven development.** Do not guess — read the relevant spec in `docs/` before implementing.

- **Scaffolding from scratch:** Follow `docs/SCAFFOLDING_GUIDE.md` phases 1–4 in order.
- **Anything else:** Use `docs/SPECIFICATION_INDEX.md` — it maps each task to the right spec (API shapes → `API_SCHEMAS.md`, backend logic → `BACKEND_SERVICES_SPEC.md`, DB → `DATA_MODEL.md`, frontend → `ARCHITECTURE.md` + `IMPLEMENTATION_SPEC.md`, etc.).

All code structure, validation, and implementation details live in those spec documents; this file only points to them.

## When in Doubt

- **Implementation:** Read `docs/SPECIFICATION_INDEX.md` and the spec it points to for your task.
- **Issues/commits:** Read `.github/prompts/ISSUE_PROMPT.md` and `.github/prompts/COMMIT_PROMPT.md`.
