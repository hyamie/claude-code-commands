---
name: map-codebase
description: Analyze unfamiliar codebase with parallel agents
---

# Map Codebase

Spawn parallel research agents to analyze a codebase you're unfamiliar with. Creates a comprehensive analysis document for quick onboarding.

## When to Use

- Picking up a project you haven't touched in months
- Starting work on someone else's codebase
- Before creating a roadmap for an existing project
- When /continue shows stale session state and you need fresh context

## Process

1. **Spawn 5 parallel research agents** using the Task tool with subagent_type=researcher, model="sonnet":

| Agent | Focus Area | What to Find |
|-------|------------|--------------|
| **Stack Agent** | Technology detection | Languages, frameworks, package managers, build tools |
| **Architecture Agent** | Code structure | Directory layout, entry points, module organization, patterns (MVC, etc.) |
| **Data Agent** | Data layer | Database type, ORM, migrations, schemas, external APIs |
| **Test Agent** | Testing setup | Test framework, coverage, test locations, how to run tests |
| **Ops Agent** | DevOps/Deployment | CI/CD, Docker, deploy scripts, env vars, hosting platform |

2. **Each agent prompt template:**

```
Analyze this codebase for [FOCUS AREA].

Find:
- [specific items from "What to Find" column]

Check these locations:
- [relevant file patterns for this focus]

Output: Bullet points only. Be specific (file paths, versions, commands).
Do NOT make changes. Research only.
```

3. **Synthesize results** into `.claude/codebase-analysis.md`:

```markdown
# Codebase Analysis

Generated: [timestamp]

## Stack
- Language: [e.g., TypeScript 5.3]
- Framework: [e.g., Next.js 14 with App Router]
- Package Manager: [e.g., pnpm]
- Build: [e.g., turbo]

## Architecture
- Pattern: [e.g., Feature-based modules]
- Entry Points: [list main files]
- Key Directories:
  - `src/app/` - Next.js routes
  - `src/lib/` - Shared utilities
  - `src/components/` - React components

## Data Layer
- Database: [e.g., PostgreSQL via Supabase]
- ORM: [e.g., Prisma]
- Migrations: [location and how to run]
- External APIs: [list integrations]

## Testing
- Framework: [e.g., Vitest + Playwright]
- Run Tests: `[command]`
- Coverage: [location/command]
- Test Locations: `tests/`, `**/*.test.ts`

## Operations
- CI/CD: [e.g., GitHub Actions]
- Deploy: [e.g., Railway via `railway up`]
- Docker: [yes/no, dockerfile location]
- Env Vars: [.env.example location, required vars]

## Quick Commands
```bash
# Install
[command]

# Dev
[command]

# Test
[command]

# Build
[command]

# Deploy
[command]
```

## Notes
- [Any gotchas or unusual patterns discovered]
```

4. **Display summary** to user after saving

## Example Invocation

```
User: /map-codebase

Claude: Spawning 5 research agents to analyze this codebase...

[Launches 5 parallel Task agents]

[Waits for results]

[Synthesizes into .claude/codebase-analysis.md]

Analysis complete. Key findings:

- **Stack:** Next.js 14 + TypeScript + Tailwind
- **Database:** Supabase (PostgreSQL)
- **Tests:** Vitest (run: `pnpm test`)
- **Deploy:** Railway (`railway up`)

Full analysis saved to `.claude/codebase-analysis.md`

Ready to work on this project. What would you like to do?
```

## Notes

- This is READ-ONLY - agents don't modify anything
- Results cached in `.claude/codebase-analysis.md` - delete to regenerate
- Works best with established projects (not empty templates)
- If a focus area finds nothing, agent reports "Not configured" rather than guessing
