# AGENTS.md — claude-code-commands

> Repo-specific Codex guidance. Global behavioral directives (outcome-driven, anti-exploration,
> batch-reads) live in ~/.codex/AGENTS.md and apply on top of this.

## What this is
A published collection of Claude Code slash commands (the `/forge` multi-model build pipeline plus
~40 planning/execution/verification/session commands). Each command is a standalone Markdown prompt.

## Stack
No code, no build — just Markdown command definitions installed into a project's `.claude/commands/`.

## Verify — run after every change (mandatory)
```bash
# no automated checks configured in this repo (Markdown-only; no tests/lint/build)
```

## Where things live
- `commands/`: one `.md` file per slash command (e.g. `forge.md`, `cook.md`, `plan.md`).
- `README.md`: pipeline overview, command index, install/customization notes.
