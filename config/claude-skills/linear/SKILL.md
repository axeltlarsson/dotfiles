---
name: linear
description: Interact with the Linear API (GraphQL). Use when the user mentions Linear issues, wants to list/create/update/search issues, add comments, check projects/teams, or manage issue states.
allowed-tools: Bash(linear *)
---

# Linear CLI

Use the `linear` CLI.

## Commands

```bash
linear <command> [args]
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

`--description TEXT` `--priority 0-4` `--state STATE_NAME` `--parent ISSUE_ID`

Priority: 0=None, 1=Urgent, 2=High, 3=Medium, 4=Low

## Update options

`--title TEXT` `--state STATE_NAME` `--assignee USER_ID` `--priority 0-4` `--description TEXT` `--parent ISSUE_ID`

## Examples

```bash
# List my issues
linear issues

# Get issue details (includes branchName and url)
linear issue DAT-123

# Search
linear search "login bug"

# Create issue
linear create DAT "Fix login redirect" --priority 2 --description "Users are redirected to 404"

# Create sub-issue
linear create DAT "Subtask title" --parent DAT-100

# Set parent on existing issue
linear update DAT-124 --parent DAT-100

# Transition state
linear update DAT-123 --state "In Progress"

# Add comment
linear comment DAT-123 "Deployed fix in PR #42"
```

## Git branch workflow

**Always** use `linear issue <id>` to get the `branchName` field from the Linear ticket before creating a git branch. Use that branch name — do not invent your own.

## Tips

- Run `linear --help` or `linear <command> --help` for full usage details
- Issue identifiers like `DAT-123` work as the `id` argument everywhere
- `issue` returns `branchName`, `url`, and `children` (sub-issues) in addition to details and comments
- To transition state: use `states <team-id>` to find state names, then `update <id> --state "Name"`
- `create` resolves team key and state name automatically — no need to look up UUIDs
- All output is JSON — parse fields as needed
- Comments and descriptions support markdown

$ARGUMENTS
