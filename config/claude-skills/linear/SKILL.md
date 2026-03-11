---
name: linear
description: Interact with the Linear API (GraphQL). Use when the user mentions Linear issues, wants to list/create/update/search issues, add comments, check projects/teams, or manage issue states.
allowed-tools: Bash(linear *)
---

# Linear CLI

Use the `linear` CLI. **Always use `--fields`** to request only the fields you need — this saves tokens and keeps output concise.

## Token efficiency rules

1. **Always pass `--fields`** — never dump full JSON when you only need specific values
2. Use team keys directly (e.g. `DAT`) — no need to look up UUIDs
3. Use `--fields branchName` to get branch names, not the full issue blob
4. Single field → raw value (no JSON wrapping); multiple fields → compact JSON

## `--fields` flag

Works on all subcommands. Comma-separated, dot notation for nesting.

```bash
linear issue DAT-123 --fields branchName           # → axel/dat-123-fix-bug
linear issue DAT-123 --fields identifier,title,state.name
linear teams --fields key,name                      # → compact JSON array
linear issues --fields identifier,title,state.name  # → array of objects
linear states DAT --fields name                     # → one name per line
```

Auto-unwraps nested response wrappers (`nodes`, single-key dicts, mutation `success`), so you don't need to know the GraphQL response shape.

## Commands

| Command | Description |
|---------|-------------|
| `me` | Current user info |
| `teams` | List teams |
| `issues` | My assigned issues |
| `issue <id>` | Issue details + comments |
| `search <query>` | Search issues |
| `create <team-key> <title> [opts]` | Create issue |
| `update <id> [opts]` | Update issue fields |
| `comment <id> <body>` | Add comment (markdown) |
| `states <team-key>` | List workflow states (accepts team key directly) |
| `labels` | List all labels |
| `projects` | List all projects |
| `archive <id>` | Archive an issue |

## Create options

`--description TEXT` `--priority 0-4` `--state STATE_NAME` `--parent ISSUE_ID` `--labels '["Bug"]'` `--project NAME`

## Update options

`--title TEXT` `--state STATE_NAME` `--assignee USER_ID` `--priority 0-4` `--description TEXT` `--parent ISSUE_ID` `--project NAME`

Labels for update — `--labels` accepts JSON:
- Array → replaces all labels: `--labels '["Bug", "Frontend"]'`
- Object → add/remove: `--labels '{"add": ["Bug"], "remove": ["Old"]}'`

## Examples

```bash
# Get branch name for git checkout
linear issue DAT-123 --fields branchName

# Compact issue list
linear issues --fields identifier,title,state.name,priorityLabel

# Create with labels
linear create DAT "Fix login" --priority 2 --labels '["Bug"]' --project "Q1 Sprint"

# Transition state
linear update DAT-123 --state "In Progress"

# Add a label without removing existing ones
linear update DAT-123 --labels '{"add": ["Reviewed"]}'

# List states by team key
linear states DAT --fields name,type
```

## Git branch workflow

Use `linear issue <id> --fields branchName` to get the branch name from Linear. Use that name — do not invent your own.

$ARGUMENTS
