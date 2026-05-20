# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
"""CLI for the Linear GraphQL API."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from textwrap import dedent
from typing import Any

import httpx  # ty: ignore[unresolved-import]

API_URL = "https://api.linear.app/graphql"

PRIORITY_NAMES = {
    "none": 0,
    "no": 0,
    "urgent": 1,
    "high": 2,
    "medium": 3,
    "med": 3,
    "low": 4,
}

RELATION_TYPES = {"blocks", "blocked-by", "related", "duplicate", "similar"}

PROJECT_STATES = {"planned", "started", "paused", "completed", "canceled", "backlog"}


def get_api_key() -> str:
    result = subprocess.run(
        [
            "security",
            "find-generic-password",
            "-a",
            "linear",
            "-s",
            "linear-api-key",
            "-w",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def gql(query: str, variables: dict[str, Any] | None = None) -> dict[str, Any]:
    headers = {
        "Content-Type": "application/json",
        "Authorization": get_api_key(),
    }
    payload: dict[str, Any] = {"query": query}
    if variables:
        payload["variables"] = variables
    resp = httpx.post(API_URL, headers=headers, json=payload, timeout=30)
    data = resp.json()
    if "errors" in data:
        print(json.dumps(data["errors"], indent=2), file=sys.stderr)
        sys.exit(1)
    resp.raise_for_status()
    return data["data"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _looks_like_uuid(s: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", s, re.I))


def resolve_issue_uuid(identifier: str) -> str:
    """Resolve an issue identifier (e.g. DAT-123) to its UUID."""
    if _looks_like_uuid(identifier):
        return identifier
    data = gql(
        "query IssueId($id: String!) { issue(id: $id) { id } }",
        {"id": identifier},
    )
    return data["issue"]["id"]


def resolve_team_id(key_or_uuid: str) -> str:
    """Resolve a team key (e.g. DAT) or UUID to a team UUID."""
    if _looks_like_uuid(key_or_uuid):
        return key_or_uuid
    teams_data = gql("{ teams { nodes { id key } } }")
    for team in teams_data["teams"]["nodes"]:
        if team["key"].upper() == key_or_uuid.upper():
            return team["id"]
    print(f"Team with key '{key_or_uuid}' not found", file=sys.stderr)
    sys.exit(1)


def resolve_project_id(name_or_uuid: str) -> str:
    """Resolve a project name (case-insensitive) or UUID to a project UUID."""
    if _looks_like_uuid(name_or_uuid):
        return name_or_uuid
    data = gql("{ projects(first: 100) { nodes { id name } } }")
    for proj in data["projects"]["nodes"]:
        if proj["name"].lower() == name_or_uuid.lower():
            return proj["id"]
    print(f"Project '{name_or_uuid}' not found", file=sys.stderr)
    sys.exit(1)


def fetch_all_labels() -> list[dict[str, str]]:
    """Fetch all labels using cursor pagination."""
    all_labels: list[dict[str, str]] = []
    cursor: str | None = None
    while True:
        after = f', after: "{cursor}"' if cursor else ""
        query = "{ issueLabels(first: 100" + after + ") { nodes { id name } pageInfo { hasNextPage endCursor } } }"
        data = gql(query)
        all_labels.extend(data["issueLabels"]["nodes"])
        page_info = data["issueLabels"]["pageInfo"]
        if not page_info["hasNextPage"]:
            break
        cursor = page_info["endCursor"]
    return all_labels


def resolve_label_ids(label_names: list[str]) -> list[str]:
    """Resolve label names (case-insensitive) to IDs."""
    lookup: dict[str, str] = {}
    for label in fetch_all_labels():
        lookup[label["name"].lower()] = label["id"]
    ids: list[str] = []
    for name in label_names:
        lid = lookup.get(name.lower())
        if not lid:
            print(f"Label '{name}' not found", file=sys.stderr)
            sys.exit(1)
        ids.append(lid)
    return ids


def resolve_label_id(name: str) -> str:
    """Resolve a single label name to id."""
    return resolve_label_ids([name])[0]


def fetch_all_users() -> list[dict[str, str]]:
    """Fetch all workspace users."""
    out: list[dict[str, str]] = []
    cursor: str | None = None
    while True:
        after = f', after: "{cursor}"' if cursor else ""
        q = "{ users(first: 250" + after + ") { nodes { id name displayName email active } pageInfo { hasNextPage endCursor } } }"
        data = gql(q)
        out.extend(data["users"]["nodes"])
        page = data["users"]["pageInfo"]
        if not page["hasNextPage"]:
            break
        cursor = page["endCursor"]
    return out


def resolve_user_id(spec: str) -> str:
    """Resolve a user spec to a UUID.

    Accepts: 'me', a UUID, an email, a name (case-insensitive), or a displayName.
    """
    if spec == "me":
        return gql("{ viewer { id } }")["viewer"]["id"]
    if _looks_like_uuid(spec):
        return spec
    users = fetch_all_users()
    spec_lower = spec.lower()
    # Prefer email match
    for u in users:
        if (u.get("email") or "").lower() == spec_lower:
            return u["id"]
    for u in users:
        if (u.get("displayName") or "").lower() == spec_lower:
            return u["id"]
    for u in users:
        if (u.get("name") or "").lower() == spec_lower:
            return u["id"]
    # Substring fallback on name/displayName
    matches = [
        u for u in users
        if spec_lower in (u.get("name") or "").lower()
        or spec_lower in (u.get("displayName") or "").lower()
    ]
    if len(matches) == 1:
        return matches[0]["id"]
    if len(matches) > 1:
        names = ", ".join(m["name"] for m in matches)
        print(f"User '{spec}' is ambiguous: {names}", file=sys.stderr)
        sys.exit(1)
    print(f"User '{spec}' not found", file=sys.stderr)
    sys.exit(1)


def resolve_cycle_id(team_id: str, spec: str) -> str:
    """Resolve a cycle spec ('current', 'next', 'previous', name, number, or UUID) to cycle UUID."""
    if _looks_like_uuid(spec):
        return spec
    q = """
    query TeamCycles($id: String!) {
      team(id: $id) {
        activeCycle { id name number }
        cycles(first: 100) {
          nodes { id name number isActive isNext isPrevious startsAt }
        }
      }
    }
    """
    data = gql(q, {"id": team_id})
    team = data["team"]
    cycles = team["cycles"]["nodes"]
    spec_lower = spec.lower()
    if spec_lower == "current" or spec_lower == "active":
        ac = team.get("activeCycle")
        if ac:
            return ac["id"]
        for c in cycles:
            if c.get("isActive"):
                return c["id"]
        print("No active cycle for this team", file=sys.stderr)
        sys.exit(1)
    if spec_lower == "next":
        for c in cycles:
            if c.get("isNext"):
                return c["id"]
        print("No next cycle for this team", file=sys.stderr)
        sys.exit(1)
    if spec_lower in ("previous", "prev", "last"):
        for c in cycles:
            if c.get("isPrevious"):
                return c["id"]
        print("No previous cycle for this team", file=sys.stderr)
        sys.exit(1)
    # By number
    if spec.isdigit():
        n = int(spec)
        for c in cycles:
            if c.get("number") == n:
                return c["id"]
    # By name
    for c in cycles:
        if (c.get("name") or "").lower() == spec_lower:
            return c["id"]
    print(f"Cycle '{spec}' not found", file=sys.stderr)
    sys.exit(1)


def parse_priority(spec: str) -> int:
    """Parse a priority spec (int 0-4 or name) into the canonical int."""
    s = spec.strip().lower()
    if s.isdigit():
        v = int(s)
        if 0 <= v <= 4:
            return v
        print(f"Priority {v} out of range 0-4", file=sys.stderr)
        sys.exit(1)
    if s in PRIORITY_NAMES:
        return PRIORITY_NAMES[s]
    print(f"Unknown priority '{spec}'. Use 0-4 or urgent|high|medium|low|none", file=sys.stderr)
    sys.exit(1)


def parse_when(spec: str) -> str:
    """Parse a 'when' spec into an ISO-8601 timestamp with timezone.

    Accepts:
      - +Nh, +Nd, +Nm (minutes), +Nw (weeks)
      - YYYY-MM-DD (interpreted as 09:00 local)
      - YYYY-MM-DDTHH:MM[:SS][Z|+offset]
    """
    s = spec.strip()
    m = re.fullmatch(r"\+(\d+)([mhdw])", s)
    if m:
        n, unit = int(m.group(1)), m.group(2)
        delta = {
            "m": timedelta(minutes=n),
            "h": timedelta(hours=n),
            "d": timedelta(days=n),
            "w": timedelta(weeks=n),
        }[unit]
        return (datetime.now(timezone.utc) + delta).isoformat()
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", s):
        dt = datetime.fromisoformat(s + "T09:00:00").astimezone()
        return dt.isoformat()
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.astimezone()
        return dt.isoformat()
    except ValueError:
        print(f"Could not parse time '{spec}'. Use +Nh, +Nd, YYYY-MM-DD, or full ISO-8601", file=sys.stderr)
        sys.exit(1)


def parse_due(spec: str) -> str:
    """Parse a due-date spec into TimelessDate (YYYY-MM-DD)."""
    s = spec.strip()
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", s):
        return s
    m = re.fullmatch(r"\+(\d+)([dw])", s)
    if m:
        n, unit = int(m.group(1)), m.group(2)
        delta = timedelta(days=n) if unit == "d" else timedelta(weeks=n)
        return (datetime.now().date() + delta).isoformat()
    print(f"Could not parse due date '{spec}'. Use YYYY-MM-DD or +Nd/+Nw", file=sys.stderr)
    sys.exit(1)


def resolve_state_id(team_id: str, state_name: str) -> str:
    states_data = gql(
        "query TeamStates($teamId: String!) {"
        " team(id: $teamId) { states { nodes { id name } } } }",
        {"teamId": team_id},
    )
    for state in states_data["team"]["states"]["nodes"]:
        if state["name"].lower() == state_name.lower():
            return state["id"]
    print(f"State '{state_name}' not found for team", file=sys.stderr)
    sys.exit(1)


def parse_labels_for_update(labels_json: str, issue_id: str) -> list[str]:
    """Parse --labels JSON for update: array (replace) or {add, remove, set}."""
    spec = json.loads(labels_json)

    if isinstance(spec, list):
        return resolve_label_ids(spec)

    if not isinstance(spec, dict):
        print("--labels must be a JSON array or object", file=sys.stderr)
        sys.exit(1)

    if "set" in spec:
        return resolve_label_ids(spec["set"])

    # Need current labels for add/remove
    current_data = gql(
        "query($id: String!) { issue(id: $id) { labels { nodes { id name } } } }",
        {"id": issue_id},
    )
    current_ids = [lbl["id"] for lbl in current_data["issue"]["labels"]["nodes"]]
    current_names = {
        lbl["name"].lower(): lbl["id"]
        for lbl in current_data["issue"]["labels"]["nodes"]
    }

    result_ids = set(current_ids)

    if "add" in spec:
        add_ids = resolve_label_ids(spec["add"])
        result_ids.update(add_ids)

    if "remove" in spec:
        remove_names = [n.lower() for n in spec["remove"]]
        for name in remove_names:
            rid = current_names.get(name)
            if rid:
                result_ids.discard(rid)

    return list(result_ids)


# ---------------------------------------------------------------------------
# --fields output filtering
# ---------------------------------------------------------------------------


def _get_nested(obj: Any, path: str) -> Any:
    """Get a nested value by dot-separated path."""
    for key in path.split("."):
        if isinstance(obj, dict):
            obj = obj.get(key)
        else:
            return None
    return obj


def _auto_unwrap(data: Any) -> Any:
    """Auto-unwrap single-key dicts and nodes arrays for ergonomic field access."""
    if isinstance(data, dict):
        # Skip 'success' key from mutations, unwrap to entity
        keys = [k for k in data if k != "success"]
        if len(keys) == 1:
            inner = data[keys[0]]
            return _auto_unwrap(inner)
    if isinstance(data, dict) and "nodes" in data and len(data) == 1:
        return data["nodes"]
    return data


def filter_fields(data: Any, fields: list[str]) -> Any:
    """Filter data to only include specified fields."""
    unwrapped = _auto_unwrap(data)

    if isinstance(unwrapped, list):
        return [_extract_fields(item, fields) for item in unwrapped]
    return _extract_fields(unwrapped, fields)


def _extract_fields(obj: Any, fields: list[str]) -> Any:
    """Extract specified fields from a single object."""
    if not isinstance(obj, dict):
        return obj
    if len(fields) == 1:
        return _get_nested(obj, fields[0])
    return {f: _get_nested(obj, f) for f in fields}


def format_output(data: Any, fields: list[str] | None, raw: bool) -> str:
    """Format data for output, applying --fields filtering if specified."""
    if raw:
        return json.dumps(data, indent=2)
    if fields is not None:
        data = filter_fields(data, fields)
        # Single field + scalar → raw value (no JSON, no quotes)
        if len(fields) == 1:
            if isinstance(data, list):
                # List of scalars → one per line
                if data and not isinstance(data[0], (dict, list)):
                    return "\n".join(str(v) for v in data)
            elif not isinstance(data, (dict, list)):
                return str(data) if data is not None else ""
    return json.dumps(data, indent=2)


# ---------------------------------------------------------------------------
# Commands — each returns data, main() handles output
# ---------------------------------------------------------------------------


def cmd_me(_args: argparse.Namespace) -> Any:
    return gql("{ viewer { id name email displayName admin active } }")


def cmd_teams(_args: argparse.Namespace) -> Any:
    return gql("{ teams { nodes { id name key } } }")


def cmd_users(_args: argparse.Namespace) -> Any:
    return {"users": {"nodes": fetch_all_users()}}


def _paginate_issues(filter_obj: dict[str, Any] | None, limit: int, fetch_all: bool, include_archived: bool) -> dict[str, Any]:
    """Paginate the issues query with the given filter."""
    out: list[dict[str, Any]] = []
    cursor: str | None = None
    page_size = min(limit, 100) if not fetch_all else 100
    while True:
        variables: dict[str, Any] = {"first": page_size}
        if cursor:
            variables["after"] = cursor
        if filter_obj is not None:
            variables["filter"] = filter_obj
        if include_archived:
            variables["includeArchived"] = True
        q = """
        query Issues($first: Int!, $after: String, $filter: IssueFilter, $includeArchived: Boolean) {
          issues(first: $first, after: $after, filter: $filter, includeArchived: $includeArchived, orderBy: updatedAt) {
            nodes {
              id identifier title
              state { name }
              priority priorityLabel
              assignee { name }
              project { name }
              cycle { number name }
              labels { nodes { name } }
              dueDate estimate
              updatedAt
            }
            pageInfo { hasNextPage endCursor }
          }
        }
        """
        data = gql(q, variables)
        out.extend(data["issues"]["nodes"])
        page = data["issues"]["pageInfo"]
        if not fetch_all and len(out) >= limit:
            out = out[:limit]
            break
        if not page["hasNextPage"]:
            break
        cursor = page["endCursor"]
    return {"issues": {"nodes": out}}


def cmd_issues(args: argparse.Namespace) -> Any:
    """List issues. With no filter flags, defaults to viewer's assigned issues."""
    filter_parts: dict[str, Any] = {}

    has_filter = any([
        args.team, args.state, args.assignee, args.project,
        args.label, args.priority is not None, args.parent,
    ])

    if not has_filter:
        # Default: viewer's assigned issues
        filter_parts["assignee"] = {"id": {"eq": resolve_user_id("me")}}
    else:
        if args.team:
            filter_parts["team"] = {"key": {"eq": args.team.upper()}}
        if args.state:
            filter_parts["state"] = {"name": {"eq": args.state}}
        if args.assignee:
            if args.assignee.lower() == "none":
                filter_parts["assignee"] = {"null": True}
            else:
                filter_parts["assignee"] = {"id": {"eq": resolve_user_id(args.assignee)}}
        if args.project:
            filter_parts["project"] = {"id": {"eq": resolve_project_id(args.project)}}
        if args.label:
            label_ids = [resolve_label_id(name) for name in args.label]
            filter_parts["labels"] = {"some": {"id": {"in": label_ids}}}
        if args.priority is not None:
            filter_parts["priority"] = {"eq": parse_priority(args.priority)}
        if args.parent:
            filter_parts["parent"] = {"id": {"eq": resolve_issue_uuid(args.parent)}}

    filter_obj = filter_parts if filter_parts else None
    return _paginate_issues(filter_obj, args.limit, args.all, args.include_archived)


def cmd_children(args: argparse.Namespace) -> Any:
    """List sub-issues of a parent."""
    parent_uuid = resolve_issue_uuid(args.id)
    filter_obj: dict[str, Any] = {"parent": {"id": {"eq": parent_uuid}}}
    return _paginate_issues(filter_obj, args.limit, args.all, args.include_archived)


def cmd_issue(args: argparse.Namespace) -> Any:
    query = """
    query IssueDetail($id: String!) {
      issue(id: $id) {
        id identifier title description url branchName
        state { id name }
        team { id key name }
        assignee { id name }
        project { id name }
        cycle { id number name }
        labels { nodes { id name } }
        priority priorityLabel
        estimate dueDate snoozedUntilAt
        createdAt updatedAt
        parent { identifier title }
        children { nodes { id identifier title state { name } } }
        subscribers { nodes { id name } }
        relations { nodes { id type relatedIssue { identifier title } } }
        inverseRelations { nodes { id type issue { identifier title } } }
        attachments { nodes { id title subtitle url } }
        comments { nodes { body user { name } createdAt } }
      }
    }
    """
    return gql(query, {"id": args.id})


def cmd_search(args: argparse.Namespace) -> Any:
    out: list[dict[str, Any]] = []
    cursor: str | None = None
    page_size = min(args.limit, 50) if not args.all else 50
    while True:
        variables: dict[str, Any] = {"term": args.query, "first": page_size}
        if cursor:
            variables["after"] = cursor
        q = """
        query SearchIssues($term: String!, $first: Int!, $after: String) {
          searchIssues(term: $term, first: $first, after: $after) {
            nodes {
              id identifier title
              state { name }
              team { key }
              assignee { name }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
        """
        data = gql(q, variables)
        out.extend(data["searchIssues"]["nodes"])
        page = data["searchIssues"]["pageInfo"]
        if not args.all and len(out) >= args.limit:
            out = out[: args.limit]
            break
        if not page["hasNextPage"]:
            break
        cursor = page["endCursor"]
    return {"searchIssues": {"nodes": out}}


def _build_issue_input(args: argparse.Namespace, team_id: str | None) -> dict[str, Any]:
    """Build the shared subset of IssueCreate/UpdateInput from args."""
    fields: dict[str, Any] = {}
    if args.description is not None:
        fields["description"] = args.description
    if args.priority is not None:
        fields["priority"] = parse_priority(args.priority)
    if args.state:
        if team_id is None:
            raise RuntimeError("team_id required to resolve state")
        fields["stateId"] = resolve_state_id(team_id, args.state)
    if args.parent:
        fields["parentId"] = resolve_issue_uuid(args.parent)
    if args.project:
        fields["projectId"] = resolve_project_id(args.project)
    if args.assignee:
        fields["assigneeId"] = resolve_user_id(args.assignee)
    if args.due:
        fields["dueDate"] = parse_due(args.due)
    if args.estimate is not None:
        fields["estimate"] = args.estimate
    if args.cycle:
        if team_id is None:
            raise RuntimeError("team_id required to resolve cycle")
        fields["cycleId"] = resolve_cycle_id(team_id, args.cycle)
    return fields


def cmd_create(args: argparse.Namespace) -> Any:
    team_id = resolve_team_id(args.team_key)

    input_fields: dict[str, Any] = {"teamId": team_id, "title": args.title}
    input_fields.update(_build_issue_input(args, team_id))

    if args.labels:
        label_names = json.loads(args.labels)
        if not isinstance(label_names, list):
            print("--labels for create must be a JSON array", file=sys.stderr)
            sys.exit(1)
        input_fields["labelIds"] = resolve_label_ids(label_names)

    query = """
    mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue { id identifier title url }
      }
    }
    """
    return gql(query, {"input": input_fields})


def cmd_update(args: argparse.Namespace) -> Any:
    input_fields: dict[str, Any] = {}
    if args.title:
        input_fields["title"] = args.title

    # State/cycle need the issue's team. Look it up once if any of those are set.
    team_id: str | None = None
    if args.state or args.cycle:
        issue_data = gql(
            "query IssueTeam($id: String!) { issue(id: $id) { team { id } } }",
            {"id": args.id},
        )
        team_id = issue_data["issue"]["team"]["id"]

    input_fields.update(_build_issue_input(args, team_id))

    if args.labels:
        input_fields["labelIds"] = parse_labels_for_update(args.labels, args.id)

    if not input_fields:
        print("No fields to update", file=sys.stderr)
        sys.exit(1)

    query = """
    mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue {
          id identifier title
          state { name } assignee { name }
          labels { nodes { name } }
          dueDate estimate cycle { number name }
        }
      }
    }
    """
    return gql(query, {"id": args.id, "input": input_fields})


def cmd_comment(args: argparse.Namespace) -> Any:
    issue_uuid = resolve_issue_uuid(args.id)

    query = """
    mutation CreateComment($input: CommentCreateInput!) {
      commentCreate(input: $input) {
        success
        comment { id body }
      }
    }
    """
    return gql(query, {"input": {"issueId": issue_uuid, "body": args.body}})


def cmd_states(args: argparse.Namespace) -> Any:
    team_id = resolve_team_id(args.team)
    query = """
    query TeamStates($teamId: String!) {
      team(id: $teamId) {
        states { nodes { id name type position } }
      }
    }
    """
    return gql(query, {"teamId": team_id})


def cmd_labels(_args: argparse.Namespace) -> Any:
    all_labels: list[dict[str, str]] = []
    cursor: str | None = None
    while True:
        after = f', after: "{cursor}"' if cursor else ""
        query = "{ issueLabels(first: 100" + after + ") { nodes { id name color } pageInfo { hasNextPage endCursor } } }"
        data = gql(query)
        all_labels.extend(data["issueLabels"]["nodes"])
        page_info = data["issueLabels"]["pageInfo"]
        if not page_info["hasNextPage"]:
            break
        cursor = page_info["endCursor"]
    return {"issueLabels": {"nodes": all_labels}}


def cmd_projects(args: argparse.Namespace) -> Any:
    out: list[dict[str, Any]] = []
    cursor: str | None = None
    filter_obj: dict[str, Any] | None = None
    if args.state:
        filter_obj = {"status": {"type": {"eq": args.state}}}
    page_size = min(args.limit, 100) if not args.all else 100
    while True:
        variables: dict[str, Any] = {"first": page_size}
        if cursor:
            variables["after"] = cursor
        if filter_obj is not None:
            variables["filter"] = filter_obj
        q = """
        query Projects($first: Int!, $after: String, $filter: ProjectFilter) {
          projects(first: $first, after: $after, filter: $filter) {
            nodes { id name state teams { nodes { key } } }
            pageInfo { hasNextPage endCursor }
          }
        }
        """
        data = gql(q, variables)
        out.extend(data["projects"]["nodes"])
        page = data["projects"]["pageInfo"]
        if not args.all and len(out) >= args.limit:
            out = out[: args.limit]
            break
        if not page["hasNextPage"]:
            break
        cursor = page["endCursor"]
    return {"projects": {"nodes": out}}


def cmd_cycles(args: argparse.Namespace) -> Any:
    team_id = resolve_team_id(args.team)
    q = """
    query TeamCycles($id: String!) {
      team(id: $id) {
        activeCycle { id number name }
        cycles(first: 50, orderBy: updatedAt) {
          nodes { id number name startsAt endsAt isActive isNext isPrevious progress }
        }
      }
    }
    """
    data = gql(q, {"id": team_id})
    return data["team"]["cycles"]


def cmd_archive(args: argparse.Namespace) -> Any:
    query = """
    mutation ArchiveIssue($id: String!) {
      issueArchive(id: $id) { success }
    }
    """
    return gql(query, {"id": args.id})


def cmd_unarchive(args: argparse.Namespace) -> Any:
    query = "mutation UnarchiveIssue($id: String!) { issueUnarchive(id: $id) { success } }"
    return gql(query, {"id": resolve_issue_uuid(args.id)})


def cmd_remind(args: argparse.Namespace) -> Any:
    issue_uuid = resolve_issue_uuid(args.id)
    when = parse_when(args.when)
    query = """
    mutation RemindIssue($id: String!, $reminderAt: DateTime!) {
      issueReminder(id: $id, reminderAt: $reminderAt) {
        success
        issue { id identifier title }
      }
    }
    """
    return gql(query, {"id": issue_uuid, "reminderAt": when})


def cmd_relate(args: argparse.Namespace) -> Any:
    rel = args.type.lower()
    if rel not in RELATION_TYPES:
        print(f"Unknown relation type '{args.type}'. Use one of: {', '.join(sorted(RELATION_TYPES))}", file=sys.stderr)
        sys.exit(1)
    a = resolve_issue_uuid(args.id)
    b = resolve_issue_uuid(args.other)
    # "blocked-by" = swap and use 'blocks'
    if rel == "blocked-by":
        a, b = b, a
        rel = "blocks"
    query = """
    mutation RelateIssue($input: IssueRelationCreateInput!) {
      issueRelationCreate(input: $input) {
        success
        issueRelation { id type issue { identifier } relatedIssue { identifier } }
      }
    }
    """
    return gql(query, {"input": {"issueId": a, "relatedIssueId": b, "type": rel}})


def cmd_unrelate(args: argparse.Namespace) -> Any:
    query = "mutation Unrelate($id: String!) { issueRelationDelete(id: $id) { success } }"
    return gql(query, {"id": args.id})


def cmd_subscribe(args: argparse.Namespace) -> Any:
    issue_uuid = resolve_issue_uuid(args.id)
    variables: dict[str, Any] = {"id": issue_uuid}
    if args.user:
        variables["userId"] = resolve_user_id(args.user)
    query = """
    mutation Subscribe($id: String!, $userId: String) {
      issueSubscribe(id: $id, userId: $userId) {
        success
        issue { identifier subscribers { nodes { name } } }
      }
    }
    """
    return gql(query, variables)


def cmd_unsubscribe(args: argparse.Namespace) -> Any:
    """Unsubscribe by setting subscriberIds = current - target.

    The API has no issueUnsubscribe mutation; this emulates it via issueUpdate.
    """
    issue_uuid = resolve_issue_uuid(args.id)
    target_id = resolve_user_id(args.user) if args.user else resolve_user_id("me")
    current = gql(
        "query($id: String!) { issue(id: $id) { subscribers { nodes { id } } } }",
        {"id": issue_uuid},
    )
    sub_ids = [s["id"] for s in current["issue"]["subscribers"]["nodes"] if s["id"] != target_id]
    query = """
    mutation Unsub($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue { identifier subscribers { nodes { name } } }
      }
    }
    """
    return gql(query, {"id": issue_uuid, "input": {"subscriberIds": sub_ids}})


def cmd_snooze(args: argparse.Namespace) -> Any:
    issue_uuid = resolve_issue_uuid(args.id)
    when = parse_when(args.until)
    query = """
    mutation Snooze($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue { identifier snoozedUntilAt }
      }
    }
    """
    return gql(query, {"id": issue_uuid, "input": {"snoozedUntilAt": when}})


def cmd_unsnooze(args: argparse.Namespace) -> Any:
    issue_uuid = resolve_issue_uuid(args.id)
    query = """
    mutation Unsnooze($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue { identifier snoozedUntilAt }
      }
    }
    """
    return gql(query, {"id": issue_uuid, "input": {"snoozedUntilAt": None}})


def cmd_attachments(args: argparse.Namespace) -> Any:
    q = """
    query IssueAttachments($id: String!) {
      issue(id: $id) {
        attachments { nodes { id title subtitle url createdAt } }
      }
    }
    """
    return gql(q, {"id": args.id})


def cmd_attach(args: argparse.Namespace) -> Any:
    issue_uuid = resolve_issue_uuid(args.id)
    input_fields: dict[str, Any] = {
        "issueId": issue_uuid,
        "url": args.url,
        "title": args.title,
    }
    if args.subtitle:
        input_fields["subtitle"] = args.subtitle
    if args.icon_url:
        input_fields["iconUrl"] = args.icon_url
    query = """
    mutation Attach($input: AttachmentCreateInput!) {
      attachmentCreate(input: $input) {
        success
        attachment { id title url }
      }
    }
    """
    return gql(query, {"input": input_fields})


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------


def _add_issue_input_args(p: argparse.ArgumentParser, *, for_create: bool) -> None:
    """Shared --description/--priority/--state/--parent/--labels/--project/--assignee/--due/--estimate/--cycle."""
    p.add_argument("--description", help="Issue description (markdown)")
    p.add_argument("--priority", help="0-4 or urgent|high|medium|low|none")
    p.add_argument("--state", help="Workflow state name")
    p.add_argument("--parent", help="Parent issue identifier (e.g. DAT-100)")
    p.add_argument("--project", help="Project name or UUID")
    p.add_argument("--assignee", help="User name, email, displayName, 'me', or UUID")
    p.add_argument("--due", help="Due date YYYY-MM-DD or +Nd/+Nw")
    p.add_argument("--estimate", type=int, help="Estimate (story points)")
    p.add_argument("--cycle", help="Cycle: 'current', 'next', 'previous', number, name, or UUID")
    if for_create:
        p.add_argument("--labels", help='JSON array of label names, e.g. \'["Bug", "Frontend"]\'')
    else:
        p.add_argument(
            "--labels",
            help='JSON: array to replace, or {"add": [...], "remove": [...]} to modify',
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="CLI for the Linear GraphQL API.",
        epilog=dedent("""\
            Examples:
              linear me                                    Show current user
              linear issues --fields identifier,title      Compact issue list
              linear issue DAT-123 --fields branchName     Get just branch name
              linear create DAT 'Fix bug' --priority high  Create issue
              linear update DAT-123 --state 'In Progress'  Transition state
              linear states DAT                            List states by team key
              linear remind DAT-123 +1d                    Remind in 1 day
              linear relate DAT-1 DAT-2 --type blocks      DAT-1 blocks DAT-2
              linear issues --team DAT --state Backlog     Filter issues"""),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    # Shared parent so --fields and --raw work on every subcommand
    common_parent = argparse.ArgumentParser(add_help=False)
    common_parent.add_argument(
        "--fields",
        help="Comma-separated fields to extract (dot notation for nesting, e.g. state.name)",
    )
    common_parent.add_argument(
        "--raw",
        action="store_true",
        help="Skip auto-unwrap (return the raw GraphQL response shape)",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("me", help="Current user info", parents=[common_parent])
    sub.add_parser("teams", help="List teams", parents=[common_parent])
    sub.add_parser("users", help="List workspace users", parents=[common_parent])

    p_issues = sub.add_parser(
        "issues",
        help="List issues (defaults to mine; filters override default)",
        parents=[common_parent],
    )
    p_issues.add_argument("--team", help="Team key (e.g. DAT)")
    p_issues.add_argument("--state", help="Workflow state name")
    p_issues.add_argument("--assignee", help="User name, email, 'me', 'none', or UUID")
    p_issues.add_argument("--project", help="Project name or UUID")
    p_issues.add_argument("--label", action="append", help="Label name (repeatable)")
    p_issues.add_argument("--priority", help="0-4 or urgent|high|medium|low|none")
    p_issues.add_argument("--parent", help="Parent issue identifier (children of)")
    p_issues.add_argument("--limit", type=int, default=50, help="Max results (default 50)")
    p_issues.add_argument("--all", action="store_true", help="Paginate through all results")
    p_issues.add_argument("--include-archived", action="store_true", help="Include archived issues")

    p_children = sub.add_parser("children", help="List sub-issues of a parent", parents=[common_parent])
    p_children.add_argument("id", help="Parent issue identifier (e.g. DAT-123)")
    p_children.add_argument("--limit", type=int, default=50)
    p_children.add_argument("--all", action="store_true")
    p_children.add_argument("--include-archived", action="store_true")

    p_issue = sub.add_parser("issue", help="Get issue details + comments", parents=[common_parent])
    p_issue.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    p_search = sub.add_parser("search", help="Search issues", parents=[common_parent])
    p_search.add_argument("query", help="Search query")
    p_search.add_argument("--limit", type=int, default=20)
    p_search.add_argument("--all", action="store_true")

    p_create = sub.add_parser("create", help="Create issue", parents=[common_parent])
    p_create.add_argument("team_key", help="Team key (e.g. DAT)")
    p_create.add_argument("title", help="Issue title")
    _add_issue_input_args(p_create, for_create=True)

    p_update = sub.add_parser("update", help="Update issue", parents=[common_parent])
    p_update.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_update.add_argument("--title", help="New title")
    _add_issue_input_args(p_update, for_create=False)

    p_comment = sub.add_parser("comment", help="Add comment to issue", parents=[common_parent])
    p_comment.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_comment.add_argument("body", help="Comment body (markdown)")

    p_states = sub.add_parser("states", help="List workflow states for a team", parents=[common_parent])
    p_states.add_argument("team", help="Team key (e.g. DAT) or UUID")

    p_cycles = sub.add_parser("cycles", help="List cycles for a team", parents=[common_parent])
    p_cycles.add_argument("team", help="Team key (e.g. DAT) or UUID")

    sub.add_parser("labels", help="List labels", parents=[common_parent])

    p_projects = sub.add_parser("projects", help="List projects", parents=[common_parent])
    p_projects.add_argument("--state", help=f"Filter by state ({', '.join(sorted(PROJECT_STATES))})")
    p_projects.add_argument("--limit", type=int, default=50)
    p_projects.add_argument("--all", action="store_true")

    p_archive = sub.add_parser("archive", help="Archive issue", parents=[common_parent])
    p_archive.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    p_unarchive = sub.add_parser("unarchive", help="Unarchive issue", parents=[common_parent])
    p_unarchive.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    p_remind = sub.add_parser("remind", help="Set a reminder on an issue", parents=[common_parent])
    p_remind.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_remind.add_argument("when", help="When: +Nh, +Nd, YYYY-MM-DD, or full ISO-8601")

    p_relate = sub.add_parser("relate", help="Create a relation between two issues", parents=[common_parent])
    p_relate.add_argument("id", help="Source issue identifier")
    p_relate.add_argument("other", help="Related issue identifier")
    p_relate.add_argument(
        "--type",
        default="related",
        help="blocks|blocked-by|related|duplicate|similar (default: related)",
    )

    p_unrelate = sub.add_parser("unrelate", help="Delete an issue relation by relation UUID", parents=[common_parent])
    p_unrelate.add_argument("id", help="Relation UUID (from `linear issue ... relations`)")

    p_sub = sub.add_parser("subscribe", help="Subscribe yourself (or another user) to an issue", parents=[common_parent])
    p_sub.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_sub.add_argument("--user", help="User name/email/UUID (default: you)")

    p_unsub = sub.add_parser("unsubscribe", help="Unsubscribe yourself (or another user) from an issue", parents=[common_parent])
    p_unsub.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_unsub.add_argument("--user", help="User name/email/UUID (default: you)")

    p_snooze = sub.add_parser("snooze", help="Snooze an issue until a given time", parents=[common_parent])
    p_snooze.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_snooze.add_argument("until", help="When: +Nh, +Nd, YYYY-MM-DD, or full ISO-8601")

    p_unsnooze = sub.add_parser("unsnooze", help="Clear an issue's snooze", parents=[common_parent])
    p_unsnooze.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    p_attachments = sub.add_parser("attachments", help="List attachments on an issue", parents=[common_parent])
    p_attachments.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    p_attach = sub.add_parser("attach", help="Attach a URL to an issue", parents=[common_parent])
    p_attach.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_attach.add_argument("--url", required=True, help="URL to attach")
    p_attach.add_argument("--title", required=True, help="Attachment title")
    p_attach.add_argument("--subtitle", help="Attachment subtitle")
    p_attach.add_argument("--icon-url", help="Custom icon URL")

    args = parser.parse_args()
    fields = [f.strip() for f in args.fields.split(",")] if args.fields else None

    dispatch: dict[str, Any] = {
        "me": cmd_me,
        "teams": cmd_teams,
        "users": cmd_users,
        "issues": cmd_issues,
        "children": cmd_children,
        "issue": cmd_issue,
        "search": cmd_search,
        "create": cmd_create,
        "update": cmd_update,
        "comment": cmd_comment,
        "states": cmd_states,
        "cycles": cmd_cycles,
        "labels": cmd_labels,
        "projects": cmd_projects,
        "archive": cmd_archive,
        "unarchive": cmd_unarchive,
        "remind": cmd_remind,
        "relate": cmd_relate,
        "unrelate": cmd_unrelate,
        "subscribe": cmd_subscribe,
        "unsubscribe": cmd_unsubscribe,
        "snooze": cmd_snooze,
        "unsnooze": cmd_unsnooze,
        "attachments": cmd_attachments,
        "attach": cmd_attach,
    }
    data = dispatch[args.command](args)
    print(format_output(data, fields, args.raw))


if __name__ == "__main__":
    main()
