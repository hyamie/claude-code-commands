# /update-guide — Regenerate the Dev Environment User Guide

Update the comprehensive user guide in Obsidian with the latest commands, skills, and best practices.

## Process

1. **Gather current state:**
   - List all commands in your project's `.claude/commands/` directory
   - Read the first 10 lines of each to get current descriptions
   - Count skills: `ls ~/.claude/skills/ | wc -l`
   - Count hooks from `~/.claude/settings.json`
   - Check shell modes in CLAUDE.md

2. **Read the existing guide:**
   Use the Obsidian MCP to read your guide document

3. **Update the guide:**
   Use the Obsidian MCP to write the updated guide

   Keep the same structure and style. Update:
   - Command tables (add new commands, remove deleted ones)
   - Skill/hook/agent counts
   - Best practices (add any new learnings)
   - File locations (if changed)
   - Architecture diagram (if changed)
   - "Last updated" date at the top

4. **Report what changed:**
   Show a summary of what was added, removed, or updated.

## Important

- Use `mcp__obsidian__write_note` to write the guide (NOT direct file writes)
- Preserve the existing structure — don't rewrite from scratch
- Keep it practical — this is a user reference, not exhaustive documentation
