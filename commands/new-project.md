---
name: new-project
description: Create new project with guided setup
---

# New Project Setup

Create a new project with Donnie-guided requirements gathering.

## Usage
```
/new-project my-project-name
/new-project my-project-name --maintenance  # Create in maintenance instead
```

## Process

### 1. Create Project Structure

```bash
PROJECT_NAME="${ARGUMENTS%% --*}"  # Extract project name
LOCATION="${ARGUMENTS##* }"        # Check for --maintenance flag

if [[ "$ARGUMENTS" == *"--maintenance"* ]]; then
    PROJECT_DIR="$HOME/projects/maintenance/$PROJECT_NAME"
else
    PROJECT_DIR="$HOME/projects/active/$PROJECT_NAME"
fi

# Create from template
cp -r ~/claude-env/templates/project-template "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Update CLAUDE.md with project name
sed -i "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" CLAUDE.md

echo "✅ Project created at: $PROJECT_DIR"
```

### 2. Requirements Gathering (Donnie Mode)

**Donnie's role:** Interview the user to understand the project.

**Questions to ask:**
1. What does this project do? (1-2 sentences)
2. What tech stack? (language, framework, database)
3. What are the main features? (bullet list)
4. Who uses it? (internal tool, public app, API)
5. Any integrations? (APIs, services, databases)
6. Deployment target? (local, staging, production URLs)

**Example dialogue:**
```
DONNIE: What does this project do?
USER: Task management app for teams
DONNIE: Tech stack preference?
USER: Next.js, Supabase, TypeScript
DONNIE: Main features?
USER: Task creation, assignment, comments, notifications
DONNIE: Who uses it?
USER: Internal team tool
DONNIE: Any external integrations?
USER: Slack notifications, GitHub issues sync
DONNIE: Deployment?
USER: Vercel staging + production
```

### 3. Project Specification Output

After gathering requirements, Donnie outputs to `$PROJECT_DIR/.claude/project-spec.json`:

```json
{
  "name": "project-name",
  "description": "One sentence description",
  "tech_stack": {
    "language": "TypeScript",
    "framework": "Next.js 15",
    "database": "PostgreSQL (Supabase)",
    "styling": "Tailwind CSS"
  },
  "features": [
    {
      "name": "Task Creation",
      "priority": "high",
      "status": "pending"
    },
    {
      "name": "Task Assignment",
      "priority": "high",
      "status": "pending"
    },
    {
      "name": "Comments",
      "priority": "medium",
      "status": "pending"
    },
    {
      "name": "Slack Notifications",
      "priority": "low",
      "status": "pending"
    }
  ],
  "integrations": ["Slack API", "GitHub API"],
  "deployment": {
    "staging": "https://project-staging.vercel.app",
    "production": "https://project.vercel.app"
  },
  "dependencies": {
    "mcps": ["github", "puppeteer"],
    "skills": [
      "frontend-design",
      "supabase-ops",
      "github-actions-templates",
      "deployment-pipeline-design"
    ],
    "agents": ["Donnie", "Researcher", "Builder", "Reviewer", "Deployer"]
  }
}
```

### 4. Update Project Files

```bash
# Update CLAUDE.md
cat >> "$PROJECT_DIR/CLAUDE.md" <<EOF

## Overview
$(jq -r '.description' .claude/project-spec.json)

## Tech Stack
$(jq -r '.tech_stack | to_entries | map("- \(.key): \(.value)") | join("\n")' .claude/project-spec.json)

## Features
$(jq -r '.features | map("- [ ] \(.name) (\(.priority) priority)") | join("\n")' .claude/project-spec.json)

## Deployment
- Staging: $(jq -r '.deployment.staging' .claude/project-spec.json)
- Production: $(jq -r '.deployment.production' .claude/project-spec.json)
EOF

# Update feature_list.json
jq '.features = input.features' feature_list.json .claude/project-spec.json > feature_list.tmp.json
mv feature_list.tmp.json feature_list.json

# Create .mcp.json if MCPs specified
if [ "$(jq -r '.dependencies.mcps | length' .claude/project-spec.json)" -gt 0 ]; then
    jq -n --argjson mcps "$(jq '.dependencies.mcps' .claude/project-spec.json)" \
        '{mcpServers: ($mcps | map({(. | gsub("-"; "_")): {command: "npx", args: ["-y", "@modelcontextprotocol/server-\(.)"], env: {}}}) | add)}' \
        > .mcp.json
fi
```

### 5. Final Instructions

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 Project Setup Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Location: $PROJECT_DIR

📋 Project Spec: .claude/project-spec.json
📝 Updated: CLAUDE.md, feature_list.json

🔌 MCPs configured: $(jq -r '.dependencies.mcps | join(", ")' .claude/project-spec.json)
📚 Recommended skills: $(jq -r '.dependencies.skills | join(", ")' .claude/project-spec.json)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Exit this session (type 'exit' or Ctrl+D)

2. Start new session:
   cd ~/projects/active/$PROJECT_NAME
   cld

3. Continue with Donnie:
   /continue

Donnie will load the project spec and start planning the scaffold.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Implementation Notes

- **Skills auto-load** from skill-rules.json when relevant
- **MCPs auto-connect** from .mcp.json on session start
- **Donnie interviews first** to avoid generic templates
- **Spec is source of truth** for project setup
- **User confirms before work starts** (after reload)

## Error Handling

**Project already exists:**
```
❌ Error: Project 'my-project' already exists at ~/projects/active/my-project
   Use a different name or delete the existing project first.
```

**No project name provided:**
```
❌ Error: Project name required
   Usage: /new-project <project-name>
```

**Invalid project name:**
```
❌ Error: Invalid project name. Use lowercase, hyphens only (e.g., my-project)
```
