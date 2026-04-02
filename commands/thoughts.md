# /thoughts — Evaluate Saved Research Items

Review saved articles, tools, repos, and ideas from the Life OS research pipeline. Pulls items from Supabase, evaluates each against your current dev environment, and triages with your input.

## Arguments

Optional filters via `$ARGUMENTS`:
- `--category ai_agency|dev|golf|personal|family_travel` — filter by category
- `--importance high|medium|low` — filter by importance
- `--limit N` — max items to pull (default: 20)

Examples:
```
/thoughts
/thoughts --category dev --importance high
/thoughts --limit 5
```

**Note:** `/thoughts` only shows dev-bucket + user-saved (telegram) items. HDS and MSP items are consumed by their respective OpenClaw agents (CEO, MSP) via Supabase API — not through this command.

## Process

### Step 1: Refresh System Reference

Run `/manifest` to regenerate `Infrastructure/environment-manifest.md` in Obsidian so evaluations compare against current state.

### Step 2: Load System Context

Read the environment manifest for current system knowledge:
```
mcp__obsidian__read_note(path="Infrastructure/environment-manifest.md")
```

Keep this in context — you'll compare every item against it.

### Step 3: Fetch Saved Items from Supabase

Get credentials (try 1Password first, fall back to .env.cron):
```bash
SERVICE_ROLE_KEY=$(op item get "Supabase - MyProject" --vault YourVault --field "Service Role Key" --reveal 2>/dev/null)
SUPABASE_URL="https://isjvcytbwanionrtvplq.supabase.co"

# Fallback if 1Password item doesn't exist yet
if [ -z "$SERVICE_ROLE_KEY" ]; then
  source ~/projects/active/1ife-os/.env.cron
  SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY"
fi
```

Pull active dev-bucket + user-saved items (oldest first):
```bash
curl -sf \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Accept-Profile: life_os" \
  "$SUPABASE_URL/rest/v1/saved_items?status=eq.active&order=captured_at.asc&limit=20&or=(routed_to.cs.{dev},captured_from.eq.telegram)"
```

Parse `$ARGUMENTS` for filters and append to the query:
- `--category X` → `&category=eq.X`
- `--importance X` → `&importance=eq.X`
- `--limit N` → change `&limit=N`

If zero items returned, tell the user "inbox zero — nothing to review" and stop.

### Step 4: Process Each Item (Loop)

For each item, do all of the following:

#### 4a. Present the Item

Show a clean summary:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 [N of TOTAL] — TITLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 URL
📂 Category: X | ⚡ Importance: X | 📅 Saved: DATE
🎯 Routing: dev:SCORE hds:SCORE msp:SCORE → ROUTED_TO_ARRAY (primary: PRIMARY_BUCKET)

📝 Summary:
SHORT_DESCRIPTION

🤖 n8n's Take:
AI_OPINION (this came from the n8n research workflow, not you)

💡 Why (PRIMARY_BUCKET): PRIMARY_BUCKET_WHY
```

Notes on routing display:
- Show all 3 scores even if some are low — helps the user understand the evaluator's reasoning
- `routed_to` shows which buckets scored >= 4 (e.g., `[dev, hds]`)
- Show the `*_why` field for the primary bucket (dev_why, hds_why, or msp_why)
- If routing fields are null (older items without v3 scores), show "Routing: not scored" instead

#### 4b. Your Verdict

Evaluate the item. Be blunt and direct. Consider:

1. **Does your current environment already cover this?** Compare against the environment manifest.
2. **Is this relevant to the user's actual work?** User is a solo dev running an AI agency (Hyams Digital Solutions), building on finished models, not training them. Also has golf, personal, family travel interests.
3. **Is the n8n evaluation overhyped?** The n8n workflow tends to over-rate things. Downgrade inflated importance.
4. **Where would this actually apply?** It might not be relevant to your environment but could be great for other projects, infrastructure, or services. Be specific about the target.

Give a clear recommendation in 2-3 sentences. No wishy-washy "could be useful." Say what you actually think.

#### 4c. Ask Why They Saved It

Ask the user: **"Why'd you save this?"** (freeform text input via AskUserQuestion)

This is critical — they may have context that changes your verdict entirely. Maybe it looked like a dev tool but they saved it for a client pitch. Maybe it's for a project you don't know about.

After their answer, revise your verdict if warranted. If it changes things, say so explicitly.

#### 4d. Triage Decision

Use AskUserQuestion with these options:
```
1. Implement  — Worth doing. Creates an implementation plan in Obsidian.
2. Archive    — Interesting but not actionable now. Keep for later.
3. Reject     — Not useful. Stored with reason for pattern analysis.
4. Skip       — Not sure yet. Leave active, come back later.
```

**Note:** AskUserQuestion only supports 2-4 options. "Stop" is always available as "Other" (the user can type "stop" at any time). If the user types "stop", "done", "quit", or "exit" as a custom answer, exit the loop.

#### 4e. Execute the Decision

**Implement:**
1. Update Supabase:
   ```bash
   curl -sf -X PATCH \
     -H "apikey: $SERVICE_ROLE_KEY" \
     -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
     -H "Content-Profile: life_os" \
     -H "Content-Type: application/json" \
     -d '{"status": "implemented", "implemented_at": "NOW_ISO"}' \
     "$SUPABASE_URL/rest/v1/saved_items?id=eq.ITEM_ID"
   ```
2. Create Obsidian implementation note:
   ```
   mcp__obsidian__write_note(
     path="claude-code/implementation-queue/SLUG.md",
     content=<see template below>
   )
   ```

   **Implementation note template:**
   ```markdown
   # TITLE

   - **Source:** ORIGINAL_URL
   - **Category:** CATEGORY
   - **Saved:** CAPTURED_AT
   - **Triaged:** TODAY'S_DATE
   - **Target repo:** SUGGESTED_REPO_OR_PROJECT

   ## Summary
   SHORT_DESCRIPTION

   ## Why Implement
   YOUR_VERDICT + USER'S REASON FOR SAVING

   ## Action Plan
   - BULLET_1 (from action_plan_bullets if exists, otherwise generate 3-5 steps)
   - BULLET_2
   - ...

   ## Notes
   ANY_ADDITIONAL_CONTEXT
   ```

   The SLUG should be a kebab-case version of the title (e.g., "proxmox-gpu-passthrough-guide").

**Archive:**
```bash
curl -sf -X PATCH \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Profile: life_os" \
  -H "Content-Type: application/json" \
  -d '{"status": "archived", "archived_at": "NOW_ISO"}' \
  "$SUPABASE_URL/rest/v1/saved_items?id=eq.ITEM_ID"
```

**Reject:**
Ask for a one-line rejection reason (freeform AskUserQuestion: "One-line reason for rejecting?"). Then:
```bash
curl -sf -X PATCH \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Profile: life_os" \
  -H "Content-Type: application/json" \
  -d '{"status": "rejected", "metadata": EXISTING_METADATA_MERGED_WITH_{"rejected_at": "NOW_ISO", "rejection_reason": "REASON"}}' \
  "$SUPABASE_URL/rest/v1/saved_items?id=eq.ITEM_ID"
```

**Skip:**
No changes. Move to next item.

### Step 5: Summary

After all items are processed (or user stops), show a triage summary:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Thoughts Session Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Implemented: N (notes in claude-code/implementation-queue/)
📦 Archived: N
❌ Rejected: N
⏭️  Skipped: N
📋 Remaining active: N
```

## Important Rules

- **Be blunt.** If something is overhyped, say so. If the n8n eval is wrong, say so. User trusts your judgment.
- **User is NOT an ML researcher.** They build on top of finished models. Training papers, dataset curation, model architecture deep-dives are almost never relevant.
- **User's priority is hardening existing projects**, not adding new infrastructure. Weigh accordingly.
- **Every item gets the "why'd you save this?" question.** Don't skip it — context changes verdicts.
- **Use Obsidian MCP** (`mcp__obsidian__write_note`) for implementation notes. Never direct file writes.
- **Fetch the service role key fresh every time** — don't cache it across sessions.
- Topics span beyond dev: AI agency, trading systems, golf, personal, family travel — evaluate in the right context.
- If the Supabase query fails, tell the user and suggest checking the service role key in 1Password.
