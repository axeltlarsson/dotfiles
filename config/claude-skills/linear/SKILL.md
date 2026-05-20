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

## Global flags

`--fields` works on all subcommands. Comma-separated, dot notation for nesting.

```bash
linear issue DAT-123 --fields branchName            # → axel/dat-123-fix-bug
linear issue DAT-123 --fields identifier,title,state.name
linear teams --fields key,name                      # → compact JSON array
linear issues --fields identifier,title,state.name  # → array of objects
linear states DAT --fields name                     # → one name per line
```

Auto-unwraps nested response wrappers (`nodes`, single-key dicts, mutation `success`). Pass `--raw` to bypass and get the GraphQL response shape verbatim.

## Commands

| Command | Description |
|---------|-------------|
| `me` | Current user |
| `teams` | List teams |
| `users` | List workspace users |
| `issues [filters]` | List issues (defaults to mine) |
| `children <id>` | Sub-issues of a parent |
| `issue <id>` | Issue details (comments, relations, attachments, subscribers) |
| `search <query>` | Search issues |
| `create <team-key> <title> [opts]` | Create issue |
| `update <id> [opts]` | Update issue |
| `comment <id> <body>` | Add comment (markdown) |
| `states <team-key>` | Workflow states |
| `cycles <team-key>` | Cycles (sprints) |
| `labels` | All labels |
| `projects [--state X]` | List projects |
| `archive <id>` / `unarchive <id>` | Archive / unarchive |
| `remind <id> <when>` | Set reminder |
| `relate <a> <b> --type T` | Create relation |
| `unrelate <relation-uuid>` | Delete relation |
| `subscribe <id>` / `unsubscribe <id>` | Subscribe (defaults: you) |
| `snooze <id> <until>` / `unsnooze <id>` | Snooze |
| `attachments <id>` | List attachments |
| `attach <id> --url U --title T` | Attach URL |

## Issue input flags (`create` / `update`)

| Flag | Notes |
|---|---|
| `--description TEXT` | markdown |
| `--priority P` | `0..4` or `urgent\|high\|medium\|low\|none` |
| `--state NAME` | workflow state name |
| `--parent ID` | parent issue identifier |
| `--project NAME` | project name or UUID |
| `--assignee SPEC` | `me`, email, name, displayName, or UUID |
| `--due DATE` | `YYYY-MM-DD` or `+Nd` / `+Nw` |
| `--estimate N` | story points |
| `--cycle SPEC` | `current` / `next` / `previous`, cycle number, name, or UUID |
| `--labels JSON` | see Labels below |

### Labels JSON

- `create`: array of names → assigned: `--labels '["Bug"]'`
- `update`:
  - Array → replaces all: `--labels '["Bug", "Frontend"]'`
  - Object → add/remove: `--labels '{"add": ["Bug"], "remove": ["Old"]}'`

## `issues` filters

`linear issues` with no flags returns *your* assigned issues. Any filter flag overrides that default:

`--team KEY` `--state NAME` `--assignee SPEC` `--project NAME` `--label NAME` (repeatable) `--priority P` `--parent ID` `--limit N` `--all` `--include-archived`

## `relate` types

`blocks`, `blocked-by` (swaps direction), `related`, `duplicate`, `similar`.

## `when` / `until` formats

Used by `remind`, `snooze`:

- `+Nm` / `+Nh` / `+Nd` / `+Nw` (relative from now)
- `YYYY-MM-DD` (interpreted as 09:00 local)
- Full ISO-8601: `2026-05-22T14:30:00Z` or with offset

## Examples

```bash
# Branch name for git checkout
linear issue DAT-123 --fields branchName

# Filtered list
linear issues --team DAT --state "In Progress" --assignee me --limit 10 \
  --fields identifier,title,priorityLabel

# Create with cycle + due + assignee + estimate
linear create DAT "Fix login" --priority high --assignee me \
  --due 2026-05-25 --estimate 3 --cycle current --labels '["Bug"]'

# Transition state
linear update DAT-123 --state "In Progress"

# Add a label without removing existing ones
linear update DAT-123 --labels '{"add": ["Reviewed"]}'

# Remind in 1 day
linear remind DAT-123 +1d

# Relation: DAT-1 blocks DAT-2
linear relate DAT-1 DAT-2 --type blocks

# Attach a PR
linear attach DAT-123 --url https://github.com/org/repo/pull/42 --title "PR #42"

# List sub-issues
linear children DAT-100 --fields identifier,title,state.name

# List active-cycle issues for a team
linear cycles DAT --fields number,isActive
linear issues --team DAT --fields identifier,title,cycle.number
```

## Git branch workflow

Use `linear issue <id> --fields branchName` to get the branch name from Linear. Use that name — do not invent your own.

$ARGUMENTS
