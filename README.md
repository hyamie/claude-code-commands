# Claude Code Commands

**`/forge` — a walk-away, multi-model build pipeline for Claude Code.** Codex builds each step from a clean context brief. Claude reviews against acceptance criteria. Objective gates (lint, test, build) verify automatically. You come back to committed, reviewed, passing code.

Plus 40 more slash commands for planning, execution, verification, and session management — built around three ideas:

1. **Fresh context beats accumulated context.** Every subagent, every Codex call, every Gemini review starts with a clean slate and only the information it needs. This is why `/forge` and `/turbo` outperform long sessions — they never inherit stale assumptions.

2. **Different models catch different bugs.** Claude writes the plan. Gemini reviews it as a staff engineer. Codex proves it works. Each model family has different blind spots — using all three means fewer escape your pipeline.

3. **Signal-based iteration, not step-counting.** Commands like `/cook` and `/smoke` don't run "3 iterations." They run until the signal says stop — verification passes, the phase is complete, or a blocker appears. This prevents both under-cooking and over-engineering.

## Highlight: `/forge` — Walk-Away Multi-Model Pipeline

`/forge` is the most powerful command in this collection. You write a plan, run `/forge-prep` to generate acceptance criteria, then run `/forge` and walk away. Here's what happens:

1. **Codex builds each step** in isolation with a clean context brief
2. **Claude reviews** the output against acceptance criteria
3. **Objective gates run** (lint, typecheck, test, build) — no AI judgment, just pass/fail
4. **Auto-commits** on success, **auto-falls back** to Claude's Builder agent on Codex failure
5. **Decisions and artifacts** are logged per-step so nothing is lost

You come back to committed, reviewed, gate-passed code — or a clear report of where it stopped and why.

```bash
/plan "Build the feature"    # Write the plan
/forge-prep                  # Generate acceptance criteria + worker assignments
/forge                       # Walk away
```

The key insight: Codex gets a fresh, self-contained brief per step — not the accumulated conversation. Every step starts clean. This is why `/forge` produces better code than a long single-model session.

---

## The Pipeline

```
/prd → /plan → /plan-review → /cook or /smoke or /turbo or /forge → /prove → /ship
                ↑ Gemini                                              ↑ Codex
```

## Commands

### Requirements & Planning
| Command | What it does |
|---------|-------------|
| `/prd` | Generate a Product Requirements Document |
| `/plan` | Create implementation plan (auto-reads PRD if present) |
| `/plan-review` | Gemini reviews your plan as a staff engineer |
| `/ready` | Convert plan to `/turbo` format and save state |

### Execution
| Command | What it does | Walk-away? |
|---------|-------------|------------|
| `/cook` | Execute one phase, stop at checkpoint | No |
| `/smoke` | Execute ALL phases autonomously | Yes |
| `/turbo` | 5 parallel review agents + Codex external review | Yes |
| `/duo` | Claude architects, Codex builds (dual-model) | No |
| `/duo-next` | Advance to next `/duo` phase | No |
| `/forge` | Multi-model artifact pipeline with auto-fallback | Yes |
| `/forge-prep` | Prepare plan for `/forge` (acceptance criteria) | No |
| `/forge-continue` | Resume after `/forge` failure | No |

### Verification
| Command | What it does |
|---------|-------------|
| `/prove` | Codex generates concrete evidence code works |
| `/grill` | Codex interrogates your understanding — must pass |
| `/verify` | Run project tests/lint/typecheck |
| `/review` | Multi-model code review pipeline |

### Recovery
| Command | What it does |
|---------|-------------|
| `/scrap` | Scrap failed approach, implement elegant solution |
| `/rollback` | Revert last phase commit |
| `/forge-rollback` | Revert entire `/forge` run |

### Session Management
| Command | What it does |
|---------|-------------|
| `/done` | Commit, save state, clean up, end session |
| `/continue` | Resume from last `/done` |
| `/resume` | Resume from session state |
| `/checkpoint` | Emergency context save |
| `/recall` | Restore context after compaction |
| `/stats` / `/status` | Session and environment statistics |

### Environment
| Command | What it does |
|---------|-------------|
| `/env:audit` | Full environment audit (MCPs, CLIs, hooks) |
| `/env:discover` | Find new MCPs and tools |
| `/env:sync` | Sync reports to Obsidian vault |
| `/check-updates` | Weekly update check for all tools |
| `/update-guide` | Regenerate environment user guide |
| `/cleanup` | Kill zombies, clean temp files |
| `/hands-off` | Remind Claude to use tools, not ask you |

### Other
| Command | What it does |
|---------|-------------|
| `/new-project` | Scaffold a new project |
| `/map-codebase` | Analyze unfamiliar codebase with parallel agents |
| `/gemini` | Get Gemini's perspective on a problem |
| `/thoughts` | Drop research and ideas for processing |
| `/skills` | List available skills |
| `/review-skill-proposals` | Review auto-generated skill proposals |
| `/autonomy` | Unattended autonomous loop (Docker sandbox) |

## Installation

Copy the commands you want to your project:

```bash
# All commands
cp -r commands/ your-project/.claude/commands/

# Just the execution pipeline
for cmd in prd plan plan-review cook smoke turbo prove verify done continue; do
  cp commands/${cmd}.md your-project/.claude/commands/
done
```

Commands are standalone markdown files — each one is a complete prompt that tells Claude how to behave when you type `/<command-name>`.

## Design Philosophy

### Token Budget Awareness

Every command is designed to minimize token waste:
- Plans are capped at 200 lines when loaded into execution commands
- Reviewer prompts scope to changed files only, not full repo diffs
- Subagents get surgical context, not the whole conversation
- Session state is structured JSON, not prose

### Model Strengths

| Model | Best at | Used by |
|-------|---------|---------|
| Claude | Planning, architecture, full-context reasoning | `/plan`, `/cook`, `/smoke`, `/scrap` |
| Gemini | Adversarial review, catching blind spots | `/plan-review`, `/gemini` |
| Codex | Code-focused debugging, proving correctness | `/prove`, `/grill`, `/turbo` (review step) |

### Fresh Context Architecture

The `/forge` and `/turbo` commands spawn subagents that each start fresh:
- No inherited assumptions from prior conversation
- Each agent gets only: the plan, the changed files, and its specific role
- Results are synthesized by the parent, not passed agent-to-agent

This is why 5 parallel reviewers find more issues than 1 reviewer doing 5 passes — each one reads the code with fresh eyes.

### Signal-Based Iteration

Traditional approach: "Run 3 iterations of review."
Our approach: "Run until verification passes or you hit a blocker."

`/cook` and `/smoke` use a loop:
1. Implement the phase
2. Run verification
3. If it fails, fix and re-verify
4. If it passes, commit and move on
5. If stuck, surface the blocker

No arbitrary iteration counts. The code tells you when it's done.

## Customization

These commands reference tools and patterns from a specific environment. You'll want to adapt:

- **1Password references** → Replace `YOUR_VAULT` with your vault name
- **Codex CLI** → Install via `npm i -g @openai/codex` (requires ChatGPT Pro)
- **Gemini CLI** → Install via `npm i -g @google/gemini-cli`
- **MCP servers** → Commands reference MCPs that may not be in your setup
- **Session state** → `/done` and `/continue` use `.claude/session-resume.json`

## Credits

Core prompt patterns inspired by [Boris Cherny](https://github.com/bcherny) (Claude Code creator):
- "Prove to me this works" → `/prove`
- "Grill me on these changes" → `/grill`
- "Scrap this and implement the elegant solution" → `/scrap`
- Plan mode + staff engineer review → `/plan` + `/plan-review`

## License

MIT
