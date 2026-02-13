---
name: linear
description: Interact with the Linear API (GraphQL). Use when the user mentions Linear issues, wants to list/create/update/search issues, add comments, check projects/teams, or manage issue states.
allowed-tools: Bash(uv run *linear*)
---

# Linear CLI

Use the Python CLI at `~/.claude/skills/linear/linear.py` via `uv run`.

## Commands

```bash
uv run ~/.claude/skills/linear/linear.py <command> [args]
```

| Command | Description |
|---------|-------------|
| `me` | Current user info |
| `teams` | List teams (id, name, key) |
| `issues` | List my assigned issues |
| `issue <id>` | Get issue details + comments (e.g. `DAT-123`) |
| `search <query>` | Search issues by text |
| `create <team-key> <title> [opts]` | Create issue |
| `update <id> [opts]` | Update issue fields |
| `comment <id> <body>` | Add comment (markdown) |
| `states <team-id>` | List workflow states for a team |
| `labels` | List all labels |
| `projects` | List all projects |
| `archive <id>` | Archive an issue |

## Create options

`--description TEXT` `--priority 0-4` `--state STATE_NAME`

Priority: 0=None, 1=Urgent, 2=High, 3=Medium, 4=Low

## Update options

`--title TEXT` `--state STATE_NAME` `--assignee USER_ID` `--priority 0-4` `--description TEXT`

## Examples

```bash
# List my issues
uv run ~/.claude/skills/linear/linear.py issues

# Get issue details
uv run ~/.claude/skills/linear/linear.py issue DAT-123

# Search
uv run ~/.claude/skills/linear/linear.py search "login bug"

# Create issue
uv run ~/.claude/skills/linear/linear.py create DAT "Fix login redirect" --priority 2 --description "Users are redirected to 404"

# Transition state
uv run ~/.claude/skills/linear/linear.py update DAT-123 --state "In Progress"

# Add comment
uv run ~/.claude/skills/linear/linear.py comment DAT-123 "Deployed fix in PR #42"
```

## Tips

- Issue identifiers like `DAT-123` work as the `id` argument everywhere
- To transition state: use `states <team-id>` to find state names, then `update <id> --state "Name"`
- `create` resolves team key and state name automatically — no need to look up UUIDs
- All output is JSON — parse fields as needed
- Comments and descriptions support markdown

$ARGUMENTS
