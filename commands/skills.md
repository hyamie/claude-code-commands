---
name: skills
description: List available skills and their triggers
argument-hint: "[FILTER]"
---

# Skills - List Available Skills

Show available skills, their triggers, and usage information.

## Usage

```
/skills              # List all skills
/skills n8n          # Filter skills containing "n8n"
/skills --triggers   # Show skills with their trigger keywords
/skills --used       # Show recently used skills
```

## Process

### Step 1: Find Skills Directory

```bash
# Skills are in the master library
SKILLS_DIR="$HOME/claude-env/.claude/skills"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "ERROR: Skills directory not found at $SKILLS_DIR"
  exit 1
fi

# Count skills (directories with SKILL.md)
SKILL_COUNT=$(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" | wc -l)
echo "Found $SKILL_COUNT skills in master library"
echo ""
```

### Step 2: List Skills

**Default view:** List all skill names with descriptions.

```bash
echo "=== Available Skills ==="
echo ""

# Parse each skill's metadata
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  # Skip non-skill directories
  [[ "$skill_name" == "by-domain" || "$skill_name" == "by-type" ]] && continue
  [[ ! -f "$skill_file" ]] && continue

  # Extract description from frontmatter
  description=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^description:" | sed 's/description: *//')

  # Truncate long descriptions
  if [ ${#description} -gt 60 ]; then
    description="${description:0:57}..."
  fi

  printf "%-30s %s\n" "$skill_name" "$description"
done | sort
```

### Step 3: Show Triggers (if --triggers)

```bash
if [[ "$ARGUMENTS" == *"--triggers"* ]]; then
  echo ""
  echo "=== Skill Triggers ==="
  echo ""

  # Read skill-rules.json for auto-activation triggers
  RULES_FILE="$SKILLS_DIR/skill-rules.json"

  if [ -f "$RULES_FILE" ]; then
    cat "$RULES_FILE" | jq -r '
      .rules[] |
      "\(.skill):\n  Keywords: \(.keywords | join(", "))\n  Context: \(.context // "any")\n"
    '
  else
    echo "No skill-rules.json found"
  fi
fi
```

### Step 4: Filter Results (if filter provided)

```bash
FILTER=$(echo "$ARGUMENTS" | sed 's/--triggers//g; s/--used//g' | xargs)

if [ -n "$FILTER" ]; then
  echo ""
  echo "=== Skills matching '$FILTER' ==="
  echo ""

  for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")

    # Skip if doesn't match filter
    [[ ! "$skill_name" == *"$FILTER"* ]] && continue

    skill_file="$skill_dir/SKILL.md"
    [[ ! -f "$skill_file" ]] && continue

    description=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^description:" | sed 's/description: *//')

    echo "### $skill_name"
    echo "$description"
    echo ""

    # Show first few lines of content (usage hints)
    echo "Usage:"
    sed -n '/^## Usage/,/^##/p' "$skill_file" | head -10
    echo ""
  done
fi
```

### Step 5: Show Recently Used (if --used)

```bash
if [[ "$ARGUMENTS" == *"--used"* ]]; then
  echo ""
  echo "=== Recently Used Skills ==="
  echo ""

  # Check session analysis for skill mentions
  # Or check observability metrics if available

  echo "(Feature requires observability MCP - not yet implemented)"
  echo ""
  echo "To see skill usage, check the session analysis output"
  echo "or search conversation history for skill invocations."
fi
```

## Output Example

### Default List
```
/skills

Found 62 skills in master library

=== Available Skills ===

1password-headless           Access 1Password secrets headlessly...
accessibility-testing        Set up WCAG 2.2 accessibility testing...
api-documentation            Generate and validate OpenAPI documentation...
api-test-automation          Automate API endpoint testing...
auth-implementation-patterns Master authentication and authorization...
automation-reliability       Build reliable automations with idempoten...
canvas-design                Create beautiful visual art in .png and...
ci-cd-setup                  Detect project type and install standard...
container-debugging          Debug Docker container issues including...
...
```

### Filtered List
```
/skills n8n

=== Skills matching 'n8n' ===

### n8n-builder
Build, validate, debug, and manage n8n workflows...

Usage:
- Create workflows from natural language specs
- Validate workflow JSON structure
- Debug execution issues

### n8n-code-javascript
Write JavaScript code in n8n Code nodes...

### n8n-code-python
Write Python code in n8n Code nodes...

...
```

### With Triggers
```
/skills --triggers

=== Skill Triggers ===

n8n-builder:
  Keywords: n8n, workflow, automation
  Context: any

postgresql:
  Keywords: postgres, postgresql, database schema, migration
  Context: any

frontend-design:
  Keywords: react, vue, frontend, ui, component
  Context: any

...
```

## Quick Reference

| Command | Shows |
|---------|-------|
| `/skills` | All skills with descriptions |
| `/skills n8n` | Skills containing "n8n" |
| `/skills --triggers` | Skills with auto-activation keywords |
| `/skills db` | Database-related skills |

## Invoking Skills

To use a skill:
```
Use the Skill tool with skill: "skill-name"
```

Or reference by keyword - if auto-activation is configured, the skill will be suggested automatically.
