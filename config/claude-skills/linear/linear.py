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


def resolve_issue_uuid(identifier: str) -> str:
    """Resolve an issue identifier (e.g. DAT-123) to its UUID."""
    data = gql(
        "query IssueId($id: String!) { issue(id: $id) { id } }",
        {"id": identifier},
    )
    return data["issue"]["id"]


def cmd_me(_args: argparse.Namespace) -> None:
    data = gql("{ viewer { id name email displayName admin active } }")
    print(json.dumps(data, indent=2))


def cmd_teams(_args: argparse.Namespace) -> None:
    data = gql("{ teams { nodes { id name key } } }")
    print(json.dumps(data, indent=2))


def cmd_issues(_args: argparse.Namespace) -> None:
    data = gql(
        "{ viewer { assignedIssues(first: 50, orderBy: updatedAt) {"
        " nodes { id identifier title state { name } priority priorityLabel"
        " project { name } labels { nodes { name } } updatedAt } } } }"
    )
    print(json.dumps(data, indent=2))


def cmd_issue(args: argparse.Namespace) -> None:
    query = """
    query IssueDetail($id: String!) {
      issue(id: $id) {
        id identifier title description
        state { id name }
        team { id key name }
        assignee { id name }
        project { id name }
        labels { nodes { id name } }
        priority priorityLabel
        createdAt updatedAt
        comments { nodes { body user { name } createdAt } }
      }
    }
    """
    data = gql(query, {"id": args.id})
    print(json.dumps(data, indent=2))


def cmd_search(args: argparse.Namespace) -> None:
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
    data = gql(query, {"term": args.query})
    print(json.dumps(data, indent=2))


def cmd_create(args: argparse.Namespace) -> None:
    # Resolve team key to team ID
    teams_data = gql("{ teams { nodes { id key } } }")
    team_id = None
    for team in teams_data["teams"]["nodes"]:
        if team["key"] == args.team_key:
            team_id = team["id"]
            break
    if not team_id:
        print(f"Team with key '{args.team_key}' not found", file=sys.stderr)
        sys.exit(1)

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

    query = """
    mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue { id identifier title url }
      }
    }
    """
    data = gql(query, {"input": input_fields})
    print(json.dumps(data, indent=2))


def cmd_update(args: argparse.Namespace) -> None:
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

    if not input_fields:
        print("No fields to update", file=sys.stderr)
        sys.exit(1)

    query = """
    mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue { id identifier title state { name } assignee { name } }
      }
    }
    """
    data = gql(query, {"id": args.id, "input": input_fields})
    print(json.dumps(data, indent=2))


def cmd_comment(args: argparse.Namespace) -> None:
    issue_uuid = resolve_issue_uuid(args.id)

    query = """
    mutation CreateComment($input: CommentCreateInput!) {
      commentCreate(input: $input) {
        success
        comment { id body }
      }
    }
    """
    data = gql(query, {"input": {"issueId": issue_uuid, "body": args.body}})
    print(json.dumps(data, indent=2))


def cmd_states(args: argparse.Namespace) -> None:
    query = """
    query TeamStates($teamId: String!) {
      team(id: $teamId) {
        states { nodes { id name type position } }
      }
    }
    """
    data = gql(query, {"teamId": args.team_id})
    print(json.dumps(data, indent=2))


def cmd_labels(_args: argparse.Namespace) -> None:
    data = gql("{ issueLabels(first: 100) { nodes { id name color } } }")
    print(json.dumps(data, indent=2))


def cmd_projects(_args: argparse.Namespace) -> None:
    data = gql(
        "{ projects(first: 50) { nodes { id name state teams { nodes { key } } } } }"
    )
    print(json.dumps(data, indent=2))


def cmd_archive(args: argparse.Namespace) -> None:
    query = """
    mutation ArchiveIssue($id: String!) {
      issueArchive(id: $id) { success }
    }
    """
    data = gql(query, {"id": args.id})
    print(json.dumps(data, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description="Linear CLI")
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

    p_comment = sub.add_parser("comment", help="Add comment to issue")
    p_comment.add_argument("id", help="Issue identifier (e.g. DAT-123)")
    p_comment.add_argument("body", help="Comment body (markdown)")

    p_states = sub.add_parser("states", help="List workflow states for a team")
    p_states.add_argument("team_id", help="Team UUID")

    sub.add_parser("labels", help="List labels")
    sub.add_parser("projects", help="List projects")

    p_archive = sub.add_parser("archive", help="Archive issue")
    p_archive.add_argument("id", help="Issue identifier (e.g. DAT-123)")

    args = parser.parse_args()
    dispatch = {
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
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
