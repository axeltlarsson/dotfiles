# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
"""CLI for the Linear GraphQL API."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from textwrap import dedent
from typing import Any

import httpx  # ty: ignore[unresolved-import]

API_URL = "https://api.linear.app/graphql"


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


def resolve_issue_uuid(identifier: str) -> str:
    """Resolve an issue identifier (e.g. DAT-123) to its UUID."""
    data = gql(
        "query IssueId($id: String!) { issue(id: $id) { id } }",
        {"id": identifier},
    )
    return data["issue"]["id"]


def resolve_team_id(key_or_uuid: str) -> str:
    """Resolve a team key (e.g. DAT) or UUID to a team UUID."""
    if len(key_or_uuid) > 10 or not key_or_uuid.isalpha():
        return key_or_uuid  # already a UUID
    teams_data = gql("{ teams { nodes { id key } } }")
    for team in teams_data["teams"]["nodes"]:
        if team["key"].upper() == key_or_uuid.upper():
            return team["id"]
    print(f"Team with key '{key_or_uuid}' not found", file=sys.stderr)
    sys.exit(1)


def resolve_project_id(name_or_uuid: str) -> str:
    """Resolve a project name (case-insensitive) or UUID to a project UUID."""
    if len(name_or_uuid) > 30 and not name_or_uuid.replace("-", "").isalnum():
        return name_or_uuid
    data = gql("{ projects(first: 100) { nodes { id name } } }")
    for proj in data["projects"]["nodes"]:
        if proj["name"].lower() == name_or_uuid.lower():
            return proj["id"]
    # If it looks like a UUID, return as-is
    if len(name_or_uuid) > 20:
        return name_or_uuid
    print(f"Project '{name_or_uuid}' not found", file=sys.stderr)
    sys.exit(1)


def resolve_label_ids(label_names: list[str]) -> list[str]:
    """Resolve label names (case-insensitive) to IDs."""
    data = gql("{ issueLabels(first: 250) { nodes { id name } } }")
    lookup: dict[str, str] = {}
    for label in data["issueLabels"]["nodes"]:
        lookup[label["name"].lower()] = label["id"]
    ids: list[str] = []
    for name in label_names:
        lid = lookup.get(name.lower())
        if not lid:
            print(f"Label '{name}' not found", file=sys.stderr)
            sys.exit(1)
        ids.append(lid)
    return ids


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


def format_output(data: Any, fields: list[str] | None) -> str:
    """Format data for output, applying --fields filtering if specified."""
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


def cmd_issues(_args: argparse.Namespace) -> Any:
    return gql(
        "{ viewer { assignedIssues(first: 50, orderBy: updatedAt) {"
        " nodes { id identifier title state { name } priority priorityLabel"
        " project { name } labels { nodes { name } } updatedAt } } } }"
    )


def cmd_issue(args: argparse.Namespace) -> Any:
    query = """
    query IssueDetail($id: String!) {
      issue(id: $id) {
        id identifier title description url branchName
        state { id name }
        team { id key name }
        assignee { id name }
        project { id name }
        labels { nodes { id name } }
        priority priorityLabel
        createdAt updatedAt
        children { nodes { id identifier title state { name } } }
        comments { nodes { body user { name } createdAt } }
      }
    }
    """
    return gql(query, {"id": args.id})


def cmd_search(args: argparse.Namespace) -> Any:
    query = """
    query SearchIssues($term: String!) {
      searchIssues(term: $term, first: 20) {
        nodes {
          id identifier title
          state { name }
          team { key }
          assignee { name }
        }
      }
    }
    """
    return gql(query, {"term": args.query})


def cmd_create(args: argparse.Namespace) -> Any:
    team_id = resolve_team_id(args.team_key)

    input_fields: dict[str, Any] = {"teamId": team_id, "title": args.title}
    if args.description:
        input_fields["description"] = args.description
    if args.priority is not None:
        input_fields["priority"] = args.priority
    if args.state:
        # Resolve state name to ID
        states_data = gql(
            "query TeamStates($teamId: String!) {"
            " team(id: $teamId) { states { nodes { id name } } } }",
            {"teamId": team_id},
        )
        state_id = None
        for state in states_data["team"]["states"]["nodes"]:
            if state["name"].lower() == args.state.lower():
                state_id = state["id"]
                break
        if not state_id:
            print(
                f"State '{args.state}' not found for team {args.team_key}",
                file=sys.stderr,
            )
            sys.exit(1)
        input_fields["stateId"] = state_id
    if args.parent:
        input_fields["parentId"] = resolve_issue_uuid(args.parent)
    if args.labels:
        label_names = json.loads(args.labels)
        if not isinstance(label_names, list):
            print("--labels for create must be a JSON array", file=sys.stderr)
            sys.exit(1)
        input_fields["labelIds"] = resolve_label_ids(label_names)
    if args.project:
        input_fields["projectId"] = resolve_project_id(args.project)

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
    if args.state:
        # Need to find the issue's team first, then resolve state
        issue_data = gql(
            "query IssueTeam($id: String!) { issue(id: $id) { team { id } } }",
            {"id": args.id},
        )
        team_id = issue_data["issue"]["team"]["id"]
        states_data = gql(
            "query TeamStates($teamId: String!) {"
            " team(id: $teamId) { states { nodes { id name } } } }",
            {"teamId": team_id},
        )
        state_id = None
        for state in states_data["team"]["states"]["nodes"]:
            if state["name"].lower() == args.state.lower():
                state_id = state["id"]
                break
        if not state_id:
            print(f"State '{args.state}' not found", file=sys.stderr)
            sys.exit(1)
        input_fields["stateId"] = state_id
    if args.assignee:
        input_fields["assigneeId"] = args.assignee
    if args.priority is not None:
        input_fields["priority"] = args.priority
    if args.description:
        input_fields["description"] = args.description
    if args.parent:
        input_fields["parentId"] = resolve_issue_uuid(args.parent)
    if args.labels:
        input_fields["labelIds"] = parse_labels_for_update(args.labels, args.id)
    if args.project:
        input_fields["projectId"] = resolve_project_id(args.project)

    if not input_fields:
        print("No fields to update", file=sys.stderr)
        sys.exit(1)

    query = """
    mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue { id identifier title state { name } assignee { name } labels { nodes { name } } }
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
    return gql("{ issueLabels(first: 100) { nodes { id name color } } }")


def cmd_projects(_args: argparse.Namespace) -> Any:
    return gql(
        "{ projects(first: 50) { nodes { id name state teams { nodes { key } } } } }"
    )


def cmd_archive(args: argparse.Namespace) -> Any:
    query = """
    mutation ArchiveIssue($id: String!) {
      issueArchive(id: $id) { success }
    }
    """
    return gql(query, {"id": args.id})


def main() -> None:
    parser = argparse.ArgumentParser(
        description="CLI for the Linear GraphQL API.",
        epilog=dedent("""\
            Examples:
              linear me                                   Show current user
              linear issues --fields identifier,title      Compact issue list
              linear issue DAT-123 --fields branchName     Get just branch name
              linear create DAT 'Fix bug' --priority 2     Create issue
              linear update DAT-123 --state 'In Progress'  Transition state
              linear states DAT                            List states by team key"""),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--fields",
        help="Comma-separated fields to extract (dot notation for nesting, e.g. state.name)",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("me", help="Current user info")
    sub.add_parser("teams", help="List teams")
    sub.add_parser("issues", help="List my assigned issues")

    p_issue = sub.add_parser("issue", help="Get issue details + comments")
    p_issue.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    p_search = sub.add_parser("search", help="Search issues")
    p_search.add_argument("query", help="Search query")

    p_create = sub.add_parser("create", help="Create issue")
    p_create.add_argument("team_key", help="Team key (e.g. DAT)")
    p_create.add_argument("title", help="Issue title")
    p_create.add_argument("--description", help="Issue description (markdown)")
    p_create.add_argument(
        "--priority",
        type=int,
        choices=range(5),
        help="0=None 1=Urgent 2=High 3=Medium 4=Low",
    )
    p_create.add_argument("--state", help="Workflow state name")
    p_create.add_argument("--parent", help="Parent issue identifier (e.g. DAT-100)")
    p_create.add_argument(
        "--labels", help='JSON array of label names, e.g. \'["Bug", "Frontend"]\'',
    )
    p_create.add_argument("--project", help="Project name or UUID")

    p_update = sub.add_parser("update", help="Update issue")
    p_update.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_update.add_argument("--title", help="New title")
    p_update.add_argument("--state", help="Workflow state name")
    p_update.add_argument("--assignee", help="Assignee user ID")
    p_update.add_argument(
        "--priority",
        type=int,
        choices=range(5),
        help="0=None 1=Urgent 2=High 3=Medium 4=Low",
    )
    p_update.add_argument("--description", help="New description (markdown)")
    p_update.add_argument("--parent", help="Parent issue identifier (e.g. DAT-100)")
    p_update.add_argument(
        "--labels",
        help='JSON: array to replace, or {"add": [...], "remove": [...]} to modify',
    )
    p_update.add_argument("--project", help="Project name or UUID")

    p_comment = sub.add_parser("comment", help="Add comment to issue")
    p_comment.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_comment.add_argument("body", help="Comment body (markdown)")

    p_states = sub.add_parser("states", help="List workflow states for a team")
    p_states.add_argument("team", help="Team key (e.g. DAT) or UUID")

    sub.add_parser("labels", help="List labels")
    sub.add_parser("projects", help="List projects")

    p_archive = sub.add_parser("archive", help="Archive issue")
    p_archive.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    args = parser.parse_args()
    fields = [f.strip() for f in args.fields.split(",")] if args.fields else None

    dispatch: dict[str, Any] = {
        "me": cmd_me,
        "teams": cmd_teams,
        "issues": cmd_issues,
        "issue": cmd_issue,
        "search": cmd_search,
        "create": cmd_create,
        "update": cmd_update,
        "comment": cmd_comment,
        "states": cmd_states,
        "labels": cmd_labels,
        "projects": cmd_projects,
        "archive": cmd_archive,
    }
    data = dispatch[args.command](args)
    print(format_output(data, fields))


if __name__ == "__main__":
    main()
