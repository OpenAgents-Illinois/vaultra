# AI Tools Setup: Cursor & Claude Code

> **100% same rules:** Both tools use the same canonical file for project standards and development rules.

## Single source of truth

| What | Canonical file | Who uses it |
|------|----------------|------------|
| Project standards (issues, commits, dev/scaffolding) | **`.github/CLAUDE.md`** | **Both** — Claude Code reads it directly; Cursor rules instruct Cursor to read and follow it |
| Issue/commit format | `.github/prompts/ISSUE_PROMPT.md`, `COMMIT_PROMPT.md` | Both (via CLAUDE.md) |
| Spec content (APIs, DB, services, frontend) | **`docs/`** | Both (via CLAUDE.md → SPECIFICATION_INDEX, SCAFFOLDING_GUIDE) |

## How it works

- **Claude Code:** Reads `.github/CLAUDE.md` (and prompts it references).
- **Cursor:** `.cursor/rules/*.mdc` tell Cursor to **read and follow `.github/CLAUDE.md`** for project standards and development rules — no duplicated text, so no drift. Same file = same behavior.

## Updating rules

- **Project / dev rules:** Edit only `.github/CLAUDE.md`. Both tools will use the updated rules.
- **Spec content:** Edit only in `docs/`.
