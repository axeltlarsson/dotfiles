---
name: aikido
description: Interact with the Aikido Security API. Use when the user mentions Aikido issues, vulnerabilities, security findings, CVEs, SBOMs, compliance, code repos, containers, domains, or wants to triage/fix/ignore/snooze security issues.
allowed-tools: Bash(aikido *)
---

# Aikido Security CLI

Use the `aikido` CLI. **Always use `--fields`** to request only the fields you need.

## Token efficiency rules

1. **Always pass `--fields`** — never dump full JSON when you only need specific values
2. Use `--severity critical,high` to focus on what matters
3. Single field = raw value; multiple fields = compact JSON

## `--fields` flag

Works on all subcommands. Comma-separated, dot notation for nesting.

```bash
aikido counts --fields issues                           # just issue counts
aikido groups --fields id,title,severity,severity_score  # compact group list
aikido issue 123 --fields severity,affected_package,how_to_fix
```

## Triage workflow

```bash
# 1. Get overview
aikido counts

# 2. List critical/high issue groups (sorted by priority)
aikido groups --severity critical,high --fields id,title,severity,severity_score,time_to_fix_minutes,how_to_fix

# 3. Drill into a group
aikido group 456 --fields title,severity,how_to_fix,related_cve_ids,locations

# 4. Export individual issues for a group
aikido issues --group 456 --fields id,severity,affected_package,affected_file,code_repo_name,patched_versions,start_line,end_line

# 5. Check reachability (is it actually exploitable?)
aikido reachability 789

# 6. Get CVE context
aikido cve CVE-2024-1234
```

## AI Pentest → TDD workflow

AI pentest findings (`type: ai_pentest`) carry a full **attack analysis**: narrative,
risk, **reproduction steps with runnable commands**, remediation, and a root-cause
analysis that often names the exact file/method. This is a ready-made red/green TDD
spec — write a failing test from `reproduction_steps`, fix, confirm green.

```bash
# 1. List all pentest findings (deduplicated groups, priority-sorted)
aikido pentest --fields id,title,severity,severity_score,locations

# 2. Map to the per-repo issues (each repo = one issue; attack analysis is per-issue)
aikido pentest --issues --repo jojnts-service --fields id,severity,group_id,code_repo_name

# 3. Pull the attack analysis for a specific issue
aikido attack 309398488 --fields title,summary,risk,reproduction_steps,remediation,root_cause_analysis

# 4. (optional) Assessment status by UUID
aikido pentest-assessment <uuid>
```

The attack analysis is keyed by **issue** id (not group id): a group like "IDOR" spans
repos, and each repo's issue has its own repo-specific reproduction steps. Non-pentest
issue ids return `404 Issue not found`. Requires the `pentests:read` scope on the token.

`attackAnalysis` fields: `title`, `summary`, `description`, `risk`,
`reproduction_steps[]` (`{step_info, code_block, observed_result}`), `remediation[]`,
`root_cause_analysis`.

## Commands — Issues

| Command | Description |
|---------|-------------|
| `counts [--repo NAME] [--team ID]` | Issue counts by severity |
| `groups [--severity S] [--type T] [--repo NAME] [--page N]` | List open issue groups (priority-sorted) |
| `group <id>` | Issue group detail with how_to_fix |
| `group-tasks <id>` | Task-tracker tasks linked to a group |
| `group-notes <id> [--personal]` | Notes on an issue group |
| `issues [--status S] [--severity S] [--type T] [--repo NAME] [--group ID] [--language L]` | Export issues (rich filtering) |
| `issue <id> [--epss]` | Single issue detail |
| `issue-bulk <id,id,...>` | Bulk issue details (max 100, needs Aikido support to enable) |
| `reachability <id> [--dev-deps]` | Reachability chain for an issue |

## Commands — AI Pentest

| Command | Description |
|---------|-------------|
| `pentest [--issues] [--repo NAME] [--status S] [--page N]` | List AI pentest findings (groups; `--issues` for per-repo issues) |
| `attack <issue-id>` | Full attack analysis: narrative + reproduction steps + root cause |
| `pentest-assessment <uuid>` | Assessment status, progress, issue count |

## Commands — Issue management

| Command | Description |
|---------|-------------|
| `ignore <id> [--reason TEXT]` | Ignore an issue |
| `unignore <id>` | Unignore an issue |
| `snooze <id> <unix-ts> [--reason TEXT]` | Snooze until timestamp |
| `unsnooze <id>` | Unsnooze an issue |
| `adjust-severity <id> <critical\|high\|medium\|low> <reason>` | Adjust severity |
| `ignore-group <id> [--reason TEXT]` | Ignore entire group |
| `unignore-group <id>` | Unignore group |
| `snooze-group <id> <unix-ts> [--reason TEXT]` | Snooze group |
| `unsnooze-group <id>` | Unsnooze group |
| `adjust-group-severity <id> <severity> <reason>` | Adjust group severity |
| `note <group-id> <text> [--cve CVE-ID]` | Add note to issue group |

## Commands — Infrastructure

| Command | Description |
|---------|-------------|
| `repos` | List code repositories |
| `repo <id>` | Repository detail |
| `scan-repo <id>` | Trigger repo scan |
| `sbom <id> [--format FMT]` | Export SBOM for repo (cyclonedx, spdx, csv) |
| `containers` | List containers |
| `container <id>` | Container detail |
| `scan-container <id>` | Trigger container scan |
| `domains` | List domains |
| `scan-domain <id>` | Start domain scan |
| `clouds` | List connected clouds |
| `vms` | List virtual machines |

## Commands — Organization

| Command | Description |
|---------|-------------|
| `teams` | List teams |
| `users` | List users |
| `user <id>` | Single user detail |
| `workspace` | Workspace info |
| `compliance <soc2\|nis2\|iso27001\|cis\|cis_aws>` | Compliance overview |

## Commands — Research & Reports

| Command | Description |
|---------|-------------|
| `cve <CVE-ID>` | Get CVE details |
| `malware [--search S] [--ecosystem E] [--page N]` | Search malware packages |
| `changelog <package> <from> <to> <language>` | Changelog summary for a package upgrade |
| `licenses [--search S] [--page N]` | List & search SBOM licenses |
| `activity-log` | Activity log |
| `pr-checks` | List PR checks / CI scans |
| `sast-rules` | List SAST rules |
| `iac-rules` | List IaC rules |
| `mobile-rules` | List Mobile rules |
| `report-pdf <sections> [--team ID] [--repo-id ID]` | Export PDF report |

## Commands — Webhooks

| Command | Description |
|---------|-------------|
| `webhooks` | List webhooks |
| `add-webhook <json-config>` | Add a webhook |
| `remove-webhook <id>` | Remove a webhook |

## Escape hatch & discovery

The named commands above cover the common surface. For **any** of the ~134 public-v1
endpoints not wrapped above, use `raw` (full passthrough) and `spec` (discovery).

```bash
# Discover endpoints (method, path, summary, required scope)
aikido spec --search pentest
aikido spec --search container
aikido spec --json                       # full OpenAPI document

# Call any endpoint directly (path is relative to /public/v1)
aikido raw GET /workspace
aikido raw GET /pentests/issues/123/attackAnalysis --fields reproduction_steps
aikido raw GET /open-issue-groups -q filter_issue_type=ai_pentest -q page=0
aikido raw POST /domains/scan --body '{"domain_id": 42}'
```

`raw` supports `--fields` like every other command, repeatable `-q/--query key=value`,
and `--body` (JSON) for write methods. Use `spec --search` to find the exact path,
params, and scope before calling `raw`.

## Issue types

`open_source`, `leaked_secret`, `cloud`, `sast`, `iac`, `docker_container`, `cloud_instance`, `surface_monitoring`, `malware`, `eol`, `mobile`, `scm_security`, `ai_pentest`, `license`

## Severity levels

`critical`, `high`, `medium`, `low` — severity_score is 1-100

## Issue statuses (for --status filter)

`all`, `open`, `ignored`, `snoozed`, `closed`

## Group statuses

`new`, `todo`, `task_open`, `task_closed`, `pull_request_open`

## Effort estimation

`time_to_fix_minutes` on issue groups indicates estimated fix time. Use this to categorise:
- **Quick win**: <= 30 min
- **Medium effort**: 30-120 min
- **Significant effort**: > 120 min

## Fixing issues

When fixing open_source dependency issues:
1. Check `patched_versions` — if available, update the dependency
2. Check `reachability` — unreachable issues are lower priority
3. Check `how_to_fix` on the group for guidance
4. After fixing, trigger `scan-repo` to verify

$ARGUMENTS
