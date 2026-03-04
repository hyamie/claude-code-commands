---
name: stats
description: Show session and environment statistics
---

# Session Statistics

Display metrics for Claude Code usage and project activity.

## Process

1. **Run the Dashboard Script**

Execute the eval dashboard to get aggregated metrics:

```bash
python3 ~/claude-env/scripts/eval-dashboard.py week
```

This shows:
- Tool usage (Edit, Bash, Write counts and success rates)
- Session statistics (count, avg duration)
- Task orchestrator status
- Activity by project
- Data quality notes

2. **Quick Summary**

After running the script, summarize for the user:
```
📊 Weekly Stats
━━━━━━━━━━━━━━━━━━━━━
Operations: [total]
Sessions: [count] (avg [duration] min)
Top Tools: [tool1] ([count]), [tool2] ([count])
Top Projects: [project1], [project2]
```

3. **Optional: Check Task Status**

If the user wants task details, also check task tree:
```
# From the task orchestrator MCP
task_tree
```

## Data Sources

- **Governance logs** (`~/.claude/logs/governance/*.jsonl`): Tool usage, sessions
- **Task orchestrator** (`.claude/tasks.db`): Task state machine (if in use)
- **Observability MCP** (`.claude/observability.db`): Not currently populated

## Notes

- Dashboard reads from JSONL logs, not the observability MCP
- Task orchestrator tracks work through the 5-agent system
- Run `/stats day` or `/stats month` for different periods
