# /gemini - Fresh Perspective from Gemini

Get Gemini's take on your current work when you need a second opinion.

## Usage

```bash
/gemini                      # General sanity check
/gemini "specific question"  # Ask something specific
/gemini --stuck              # We're in a loop, need help
/gemini --plan               # Review the current plan
/gemini --alternatives       # Give me different approaches
```

## What To Do When Invoked

When the user runs `/gemini`, follow these steps:

### Step 1: Gather Context

Collect the following information:

1. **Current file** - What file is being worked on (if any)
2. **Recent errors** - Any errors from recent tool calls
3. **Conversation summary** - Brief summary of what's been tried
4. **Git diff** - Uncommitted changes (if relevant)
5. **Current plan** - From todo list or recent discussion

### Step 2: Create Context File

Write a JSON file with the gathered context:

```bash
cat > /tmp/gemini-context.json << 'EOF'
{
  "mode": "sanity",
  "current_file": "path/to/file",
  "current_file_content": "...",
  "git_diff": "...",
  "conversation_summary": "Brief summary of what we've been working on and what's been tried",
  "errors": ["error1", "error2"],
  "plan": "current plan if exists",
  "project_context": "relevant CLAUDE.md excerpts",
  "user_message": "user's specific question if any"
}
EOF
```

### Step 3: Call Gemini

```bash
python3 ~/.claude/skills/gemini/scripts/gemini_client.py \
  --context-file /tmp/gemini-context.json \
  --output-file .claude/gemini-response.md \
  --mode sanity
```

Modes:
- `sanity` - General review (default)
- `plan` - Review implementation plan
- `stuck` - Help break out of a loop
- `alternatives` - Get different approaches
- `review` - Code review

### Step 4: Report Results

After Gemini responds:

1. **Show the summary** - Display what was printed to stdout
2. **Offer full details** - Mention `.claude/gemini-response.md` is available
3. **Consider the feedback** - Don't blindly follow, but incorporate useful insights

### Step 5: Continue or Adjust

Based on Gemini's perspective:
- If it confirms our approach: proceed with confidence
- If it raises valid concerns: adjust the plan
- If it suggests alternatives: evaluate them honestly

## Example Interaction

**User:** `/gemini we've tried 3 different regex patterns and none work`

**Claude's response:**
```
Let me get Gemini's perspective on this regex issue.

[Gathers context, calls gemini_client.py]

## Gemini's Take

- The regex patterns tried are matching greedily - consider non-greedy `*?`
- Edge case: empty strings aren't being handled
- Alternative: split + filter might be cleaner than regex for this case

📄 Full response: `.claude/gemini-response.md`

Gemini raises a good point about greedy matching. Let me try the non-greedy approach...
```

## Important Notes

- **Don't blindly follow Gemini** - It's a second opinion, not gospel
- **Context is filtered** - Secrets and sensitive data are removed automatically
- **Full response is saved** - Read `.claude/gemini-response.md` for details
- **10-minute cooldown** - Auto-suggestion won't repeat within 10 minutes
