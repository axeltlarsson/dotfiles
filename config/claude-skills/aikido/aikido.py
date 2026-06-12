# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
"""CLI for the Aikido Security REST API."""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
import time
from textwrap import dedent
from typing import Any

import httpx  # ty: ignore[unresolved-import]

BASE_URL = "https://app.aikido.dev/api"
TOKEN_URL = f"{BASE_URL}/oauth/token"
PUBLIC_V1 = f"{BASE_URL}/public/v1"

_cached_token: str | None = None
_token_expires_at: float = 0


def _keychain(service: str) -> str:
    result = subprocess.run(
        ["security", "find-generic-password", "-s", service, "-w"],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def get_token() -> str:
    global _cached_token, _token_expires_at
    if _cached_token and time.time() < _token_expires_at - 60:
        return _cached_token
    client_id = _keychain("aikido-client")
    client_secret = _keychain("aikido-secret")
    creds = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    resp = httpx.post(
        TOKEN_URL,
        headers={
            "Authorization": f"Basic {creds}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={"grant_type": "client_credentials"},
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    _cached_token = data["access_token"]
    _token_expires_at = time.time() + data.get("expires_in", 3600)
    return _cached_token  # type: ignore[return-value]


def api(
    method: str, path: str, *, params: dict | None = None, body: dict | None = None
) -> Any:
    url = f"{PUBLIC_V1}{path}"
    headers = {"Authorization": f"Bearer {get_token()}"}
    resp = httpx.request(
        method, url, headers=headers, params=params, json=body, timeout=60
    )
    if resp.status_code == 204:
        return {"status": "ok"}
    if not resp.is_success:
        try:
            err = resp.json()
        except Exception:
            err = resp.text
        print(f"HTTP {resp.status_code}: {json.dumps(err, indent=2)}", file=sys.stderr)
        sys.exit(1)
    return resp.json()


# ---------------------------------------------------------------------------
# --fields output filtering (same pattern as linear CLI)
# ---------------------------------------------------------------------------


def _get_nested(obj: Any, path: str) -> Any:
    for key in path.split("."):
        if isinstance(obj, dict):
            obj = obj.get(key)
        else:
            return None
    return obj


def filter_fields(data: Any, fields: list[str]) -> Any:
    if isinstance(data, list):
        return [_extract(item, fields) for item in data]
    return _extract(data, fields)


def _extract(obj: Any, fields: list[str]) -> Any:
    if not isinstance(obj, dict):
        return obj
    if len(fields) == 1:
        return _get_nested(obj, fields[0])
    return {f: _get_nested(obj, f) for f in fields}


def fmt(data: Any, fields: list[str] | None) -> str:
    if fields is not None:
        data = filter_fields(data, fields)
        if len(fields) == 1:
            if isinstance(data, list):
                if data and not isinstance(data[0], (dict, list)):
                    return "\n".join(str(v) for v in data)
            elif not isinstance(data, (dict, list)):
                return str(data) if data is not None else ""
    return json.dumps(data, indent=2)


# ---------------------------------------------------------------------------
# Issue commands
# ---------------------------------------------------------------------------


def cmd_counts(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {}
    if args.repo:
        params["filter_code_repo_name"] = args.repo
    if args.team:
        params["filter_team_id"] = args.team
    return api("GET", "/issues/counts", params=params)


def cmd_groups(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {"page": args.page, "per_page": 20}
    if args.severity:
        # The API doesn't filter by severity directly on groups, we'll filter client-side
        pass
    if args.type:
        params["filter_issue_type"] = args.type
    if args.repo:
        params["filter_code_repo_name"] = args.repo
    if args.repo_id:
        params["filter_code_repo_id"] = args.repo_id
    if args.team:
        params["filter_team_id"] = args.team

    results = api("GET", "/open-issue-groups", params=params)

    if args.severity:
        sevs = {s.strip() for s in args.severity.split(",")}
        results = [g for g in results if g.get("severity") in sevs]
    return results


def cmd_group(args: argparse.Namespace) -> Any:
    return api("GET", f"/issues/groups/{args.id}")


def cmd_issues(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {"format": "json"}
    if args.status:
        params["filter_status"] = args.status
    if args.severity:
        params["filter_severities"] = args.severity
    if args.type:
        params["filter_issue_type"] = args.type
    if args.repo:
        params["filter_code_repo_name"] = args.repo
    if args.group:
        params["filter_issue_group_id"] = args.group
    if args.team:
        params["filter_team_id"] = args.team
    if args.language:
        params["filter_language"] = args.language
    return api("GET", "/issues/export", params=params)


def cmd_issue(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {}
    if args.epss:
        params["include_epss_score"] = "true"
    return api("GET", f"/issues/{args.id}", params=params)


def cmd_issue_bulk(args: argparse.Namespace) -> Any:
    return api("GET", "/issues/detail/bulk", params={"issue_ids": args.ids})


def cmd_reachability(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {}
    if args.dev_deps:
        params["include_dev_deps"] = "true"
    return api("GET", f"/issues/{args.id}/reachability", params=params)


# ---------------------------------------------------------------------------
# AI Pentest commands
# ---------------------------------------------------------------------------


def cmd_pentest(args: argparse.Namespace) -> Any:
    """List AI pentest findings. Groups by default; --issues for per-repo issues."""
    if args.issues:
        params: dict[str, Any] = {"format": "json", "filter_issue_type": "ai_pentest"}
        if args.repo:
            params["filter_code_repo_name"] = args.repo
        if args.status:
            params["filter_status"] = args.status
        return api("GET", "/issues/export", params=params)
    params = {"page": args.page, "per_page": 20, "filter_issue_type": "ai_pentest"}
    if args.repo:
        params["filter_code_repo_name"] = args.repo
    return api("GET", "/open-issue-groups", params=params)


def cmd_attack(args: argparse.Namespace) -> Any:
    """Get the full attack analysis (narrative + reproduction steps) for a pentest issue."""
    return api("GET", f"/pentests/issues/{args.id}/attackAnalysis")


def cmd_pentest_assessment(args: argparse.Namespace) -> Any:
    return api("GET", f"/pentests/assessments/{args.id}/detail")


def cmd_ignore(args: argparse.Namespace) -> Any:
    body: dict[str, Any] = {}
    if args.reason:
        body["reason"] = args.reason
    return api("PUT", f"/issues/{args.id}/ignore", body=body)


def cmd_unignore(args: argparse.Namespace) -> Any:
    return api("PUT", f"/issues/{args.id}/unignore")


def cmd_snooze(args: argparse.Namespace) -> Any:
    body: dict[str, Any] = {"snooze_until": args.until}
    if args.reason:
        body["reason"] = args.reason
    return api("PUT", f"/issues/{args.id}/snooze", body=body)


def cmd_unsnooze(args: argparse.Namespace) -> Any:
    return api("PUT", f"/issues/{args.id}/unsnooze")


def cmd_adjust_severity(args: argparse.Namespace) -> Any:
    return api(
        "POST",
        f"/issues/{args.id}/severity/adjust",
        body={
            "adjusted_severity": args.severity,
            "reason": args.reason,
        },
    )


def cmd_ignore_group(args: argparse.Namespace) -> Any:
    body: dict[str, Any] = {}
    if args.reason:
        body["reason"] = args.reason
    return api("PUT", f"/issues/groups/{args.id}/ignore", body=body)


def cmd_unignore_group(args: argparse.Namespace) -> Any:
    return api("PUT", f"/issues/groups/{args.id}/unignore")


def cmd_snooze_group(args: argparse.Namespace) -> Any:
    body: dict[str, Any] = {"snooze_until": args.until}
    if args.reason:
        body["reason"] = args.reason
    return api("PUT", f"/issues/groups/{args.id}/snooze", body=body)


def cmd_unsnooze_group(args: argparse.Namespace) -> Any:
    return api("PUT", f"/issues/groups/{args.id}/unsnooze")


def cmd_adjust_group_severity(args: argparse.Namespace) -> Any:
    return api(
        "POST",
        f"/issues/groups/{args.id}/severity/adjust",
        body={
            "adjusted_severity": args.severity,
            "reason": args.reason,
        },
    )


def cmd_note(args: argparse.Namespace) -> Any:
    body: dict[str, Any] = {"note": args.note}
    if args.cve:
        body["cve_id"] = args.cve
    return api("POST", f"/issues/groups/{args.id}/notes", body=body)


def cmd_group_tasks(args: argparse.Namespace) -> Any:
    return api("GET", f"/issues/groups/{args.id}/tasks")


def cmd_group_notes(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {}
    if args.personal:
        params["include_personal_notes"] = "true"
    return api("GET", f"/issues/groups/{args.id}/notes", params=params)


# ---------------------------------------------------------------------------
# Repo commands
# ---------------------------------------------------------------------------


def cmd_repos(_args: argparse.Namespace) -> Any:
    return api("GET", "/repositories/code")


def cmd_repo(args: argparse.Namespace) -> Any:
    return api("GET", f"/repositories/code/{args.id}")


def cmd_scan_repo(args: argparse.Namespace) -> Any:
    return api("POST", f"/repositories/code/{args.id}/scan")


def cmd_sbom(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {}
    if args.format:
        params["format"] = args.format
    return api("GET", f"/repositories/code/{args.id}/licenses/export", params=params)


# ---------------------------------------------------------------------------
# Container commands
# ---------------------------------------------------------------------------


def cmd_containers(_args: argparse.Namespace) -> Any:
    return api("GET", "/containers")


def cmd_container(args: argparse.Namespace) -> Any:
    return api("GET", f"/containers/{args.id}")


def cmd_scan_container(args: argparse.Namespace) -> Any:
    return api("POST", f"/containers/{args.id}/scan")


# ---------------------------------------------------------------------------
# Domain commands
# ---------------------------------------------------------------------------


def cmd_domains(_args: argparse.Namespace) -> Any:
    return api("GET", "/domains")


def cmd_scan_domain(args: argparse.Namespace) -> Any:
    return api("POST", "/domains/scan", body={"domain_id": args.id})


# ---------------------------------------------------------------------------
# Cloud commands
# ---------------------------------------------------------------------------


def cmd_clouds(_args: argparse.Namespace) -> Any:
    return api("GET", "/clouds")


# ---------------------------------------------------------------------------
# Teams, users, workspace
# ---------------------------------------------------------------------------


def cmd_teams(_args: argparse.Namespace) -> Any:
    return api("GET", "/teams")


def cmd_users(_args: argparse.Namespace) -> Any:
    return api("GET", "/users")


def cmd_user(args: argparse.Namespace) -> Any:
    return api("GET", f"/users/{args.id}")


def cmd_workspace(_args: argparse.Namespace) -> Any:
    return api("GET", "/workspace")


# ---------------------------------------------------------------------------
# Compliance
# ---------------------------------------------------------------------------

# framework name -> path segment under /report/{seg}/overview
_COMPLIANCE_PATHS = {
    "soc2": "soc2",
    "nis2": "nis2",
    "iso27001": "iso",
    "cis": "cis",
    "cis_aws": "cis_aws",
}


def cmd_compliance(args: argparse.Namespace) -> Any:
    seg = _COMPLIANCE_PATHS[args.framework]
    return api("GET", f"/report/{seg}/overview")


# ---------------------------------------------------------------------------
# Research
# ---------------------------------------------------------------------------


def cmd_cve(args: argparse.Namespace) -> Any:
    return api("GET", f"/cve/{args.id}")


def cmd_malware(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {"page": args.page, "per_page": args.per_page}
    if args.search:
        params["search"] = args.search
    if args.ecosystem:
        params["filter_ecosystem"] = args.ecosystem
    return api("GET", "/research/malware/packages", params=params)


def cmd_changelog(args: argparse.Namespace) -> Any:
    return api(
        "GET",
        "/changelog-summary",
        params={
            "package_name": args.package,
            "from_version": args.from_version,
            "to_version": args.to_version,
            "language": args.language,
        },
    )


def cmd_licenses(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {"page": args.page, "per_page": args.per_page}
    if args.search:
        params["search"] = args.search
    return api("GET", "/licenses", params=params)


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------


def cmd_activity_log(_args: argparse.Namespace) -> Any:
    return api("GET", "/report/activityLog")


def cmd_pr_checks(_args: argparse.Namespace) -> Any:
    return api("GET", "/report/ciScans")


def cmd_sast_rules(_args: argparse.Namespace) -> Any:
    return api("GET", "/repositories/code/sast/rules")


def cmd_iac_rules(_args: argparse.Namespace) -> Any:
    return api("GET", "/repositories/code/iac/rules")


def cmd_mobile_rules(_args: argparse.Namespace) -> Any:
    return api("GET", "/repositories/code/mobile/rules")


def cmd_report_pdf(args: argparse.Namespace) -> Any:
    params: dict[str, Any] = {"included_sections": args.sections}
    if args.team:
        params["team_id"] = args.team
    if args.repo_id:
        params["repo_id"] = args.repo_id
    return api("GET", "/report/export/pdf", params=params)


# ---------------------------------------------------------------------------
# Virtual machines
# ---------------------------------------------------------------------------


def cmd_vms(_args: argparse.Namespace) -> Any:
    return api("GET", "/virtual-machines")


# ---------------------------------------------------------------------------
# Webhooks
# ---------------------------------------------------------------------------


def cmd_webhooks(_args: argparse.Namespace) -> Any:
    return api("GET", "/webhooks")


def cmd_add_webhook(args: argparse.Namespace) -> Any:
    return api("POST", "/webhooks", body=json.loads(args.config))


def cmd_remove_webhook(args: argparse.Namespace) -> Any:
    return api("DELETE", f"/webhooks/{args.id}")


# ---------------------------------------------------------------------------
# Generic escape hatch + spec discovery
# ---------------------------------------------------------------------------


def cmd_raw(args: argparse.Namespace) -> Any:
    """Call any public-v1 endpoint directly. Covers the full API surface.

    Path is relative to /public/v1, e.g. /pentests/issues/123/attackAnalysis
    """
    path = args.path if args.path.startswith("/") else f"/{args.path}"
    params: dict[str, Any] = {}
    for kv in args.query or []:
        if "=" not in kv:
            print(f"--query expects key=value, got: {kv}", file=sys.stderr)
            sys.exit(2)
        k, v = kv.split("=", 1)
        params[k] = v
    body = json.loads(args.body) if args.body else None
    return api(args.method.upper(), path, params=params or None, body=body)


def cmd_spec(args: argparse.Namespace) -> Any:
    """Fetch the OpenAPI spec. Lists endpoints by default; --json for the full document."""
    spec = api("GET", "/openapi/spec")
    if args.json:
        return spec
    rows = []
    for path, methods in spec.get("paths", {}).items():
        for method, op in methods.items():
            if method not in ("get", "post", "put", "delete", "patch"):
                continue
            summary = op.get("summary", "")
            scopes = sorted(
                {s for sec in op.get("security", []) for v in sec.values() for s in v}
            )
            if args.search:
                if args.search.lower() not in f"{path} {summary}".lower():
                    continue
            rows.append(
                {
                    "method": method.upper(),
                    "path": path,
                    "summary": summary,
                    "scopes": scopes,
                }
            )
    rows.sort(key=lambda r: r["path"])
    return rows


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="CLI for the Aikido Security API.",
        epilog=dedent("""\
            Examples:
              aikido counts                                    Issue count summary
              aikido groups --severity critical,high            Critical/high issue groups
              aikido issues --status open --severity critical   Export critical open issues
              aikido issue 123                                  Single issue detail
              aikido reachability 123                           Reachability chain
              aikido pentest                                   List AI pentest findings (groups)
              aikido pentest --issues --repo jojnts-service     Pentest issues for a repo
              aikido attack 309398488                           Attack analysis + repro steps
              aikido spec --search pentest                      Discover endpoints
              aikido raw GET /workspace                         Call any endpoint directly
              aikido repos                                     List code repos
              aikido cve CVE-2024-1234                          CVE details"""),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    fp = argparse.ArgumentParser(add_help=False)
    fp.add_argument("--fields", help="Comma-separated fields to extract (dot notation)")
    sub = parser.add_subparsers(dest="command", required=True)

    # --- Issue counts ---
    p = sub.add_parser("counts", help="Get issue counts by severity", parents=[fp])
    p.add_argument("--repo", help="Filter by repo name")
    p.add_argument("--team", type=int, help="Filter by team ID")

    # --- Issue groups ---
    p = sub.add_parser(
        "groups", help="List open issue groups (sorted by priority)", parents=[fp]
    )
    p.add_argument("--page", type=int, default=0, help="Page number (0-based)")
    p.add_argument(
        "--severity", help="Filter: critical,high,medium,low (comma-separated)"
    )
    p.add_argument(
        "--type", help="Filter: open_source,leaked_secret,cloud,sast,iac,etc."
    )
    p.add_argument("--repo", help="Filter by repo name")
    p.add_argument("--repo-id", type=int, dest="repo_id", help="Filter by repo ID")
    p.add_argument("--team", type=int, help="Filter by team ID")

    # --- Issue group detail ---
    p = sub.add_parser("group", help="Get issue group detail", parents=[fp])
    p.add_argument("id", type=int, help="Issue group ID")

    # --- Export issues ---
    p = sub.add_parser(
        "issues", help="Export issues (with rich filtering)", parents=[fp]
    )
    p.add_argument(
        "--status",
        default="open",
        help="all|open|ignored|snoozed|closed (default: open)",
    )
    p.add_argument(
        "--severity", help="Filter: critical,high,medium,low (comma-separated)"
    )
    p.add_argument("--type", help="Filter by issue type")
    p.add_argument("--repo", help="Filter by repo name")
    p.add_argument("--group", type=int, help="Filter by issue group ID")
    p.add_argument("--team", type=int, help="Filter by team ID")
    p.add_argument(
        "--language", help="Filter: JS,TS,PHP,Java,PY,GO,Ruby,.NET,RUST,etc."
    )

    # --- Single issue ---
    p = sub.add_parser("issue", help="Get single issue detail", parents=[fp])
    p.add_argument("id", type=int, help="Issue ID")
    p.add_argument("--epss", action="store_true", help="Include EPSS score (Pro/Scale)")

    # --- Bulk issue detail ---
    p = sub.add_parser("issue-bulk", help="Get multiple issue details", parents=[fp])
    p.add_argument("ids", help="Comma-separated issue IDs (max 100)")

    # --- Reachability ---
    p = sub.add_parser(
        "reachability", help="Get issue reachability chain", parents=[fp]
    )
    p.add_argument("id", type=int, help="Issue ID")
    p.add_argument(
        "--dev-deps",
        action="store_true",
        dest="dev_deps",
        help="Include dev dependencies",
    )

    # --- AI Pentest ---
    p = sub.add_parser(
        "pentest",
        help="List AI pentest findings (groups; --issues for per-repo issues)",
        parents=[fp],
    )
    p.add_argument(
        "--issues", action="store_true", help="List individual issues instead of groups"
    )
    p.add_argument("--repo", help="Filter by repo name")
    p.add_argument(
        "--status",
        help="Issue status filter (with --issues): open|ignored|snoozed|closed",
    )
    p.add_argument(
        "--page", type=int, default=0, help="Page number (0-based, groups only)"
    )

    p = sub.add_parser(
        "attack",
        help="Get attack analysis (narrative + reproduction steps) for a pentest issue",
        parents=[fp],
    )
    p.add_argument("id", type=int, help="Pentest issue ID (from `pentest --issues`)")

    p = sub.add_parser(
        "pentest-assessment", help="Get pentest assessment detail", parents=[fp]
    )
    p.add_argument("id", help="Assessment UUID")

    # --- Ignore/snooze/adjust issue ---
    p = sub.add_parser("ignore", help="Ignore an issue", parents=[fp])
    p.add_argument("id", type=int)
    p.add_argument("--reason", help="Reason for ignoring")

    p = sub.add_parser("unignore", help="Unignore an issue", parents=[fp])
    p.add_argument("id", type=int)

    p = sub.add_parser("snooze", help="Snooze an issue", parents=[fp])
    p.add_argument("id", type=int)
    p.add_argument("until", type=int, help="Unix timestamp when snooze expires")
    p.add_argument("--reason", help="Reason for snoozing")

    p = sub.add_parser("unsnooze", help="Unsnooze an issue", parents=[fp])
    p.add_argument("id", type=int)

    p = sub.add_parser("adjust-severity", help="Adjust issue severity", parents=[fp])
    p.add_argument("id", type=int)
    p.add_argument("severity", choices=["critical", "high", "medium", "low"])
    p.add_argument("reason", help="Reason for adjustment")

    # --- Group-level ignore/snooze/adjust/note ---
    p = sub.add_parser("ignore-group", help="Ignore an issue group", parents=[fp])
    p.add_argument("id", type=int)
    p.add_argument("--reason", help="Reason for ignoring")

    p = sub.add_parser("unignore-group", help="Unignore an issue group", parents=[fp])
    p.add_argument("id", type=int)

    p = sub.add_parser("snooze-group", help="Snooze an issue group", parents=[fp])
    p.add_argument("id", type=int)
    p.add_argument("until", type=int, help="Unix timestamp when snooze expires")
    p.add_argument("--reason", help="Reason for snoozing")

    p = sub.add_parser("unsnooze-group", help="Unsnooze an issue group", parents=[fp])
    p.add_argument("id", type=int)

    p = sub.add_parser(
        "adjust-group-severity", help="Adjust issue group severity", parents=[fp]
    )
    p.add_argument("id", type=int)
    p.add_argument("severity", choices=["critical", "high", "medium", "low"])
    p.add_argument("reason", help="Reason for adjustment")

    p = sub.add_parser("note", help="Add note to issue group", parents=[fp])
    p.add_argument("id", type=int, help="Issue group ID")
    p.add_argument("note", help="Note text")
    p.add_argument("--cve", help="Scope note to specific CVE")

    p = sub.add_parser(
        "group-tasks", help="List tasks linked to an issue group", parents=[fp]
    )
    p.add_argument("id", type=int, help="Issue group ID")

    p = sub.add_parser("group-notes", help="List notes on an issue group", parents=[fp])
    p.add_argument("id", type=int, help="Issue group ID")
    p.add_argument("--personal", action="store_true", help="Include personal notes")

    # --- Repos ---
    sub.add_parser("repos", help="List code repositories", parents=[fp])
    p = sub.add_parser("repo", help="Get code repository detail", parents=[fp])
    p.add_argument("id", type=int)
    p = sub.add_parser("scan-repo", help="Trigger repo scan", parents=[fp])
    p.add_argument("id", type=int)
    p = sub.add_parser("sbom", help="Export SBOM for a repo", parents=[fp])
    p.add_argument("id", type=int)
    p.add_argument("--format", help="SBOM format (e.g. cyclonedx, spdx, csv)")

    # --- Containers ---
    sub.add_parser("containers", help="List containers", parents=[fp])
    p = sub.add_parser("container", help="Get container detail", parents=[fp])
    p.add_argument("id", type=int)
    p = sub.add_parser("scan-container", help="Trigger container scan", parents=[fp])
    p.add_argument("id", type=int)

    # --- Domains ---
    sub.add_parser("domains", help="List domains", parents=[fp])
    p = sub.add_parser("scan-domain", help="Start domain scan", parents=[fp])
    p.add_argument("id", type=int)

    # --- Clouds ---
    sub.add_parser("clouds", help="List connected clouds", parents=[fp])

    # --- Teams / Users / Workspace ---
    sub.add_parser("teams", help="List teams", parents=[fp])
    sub.add_parser("users", help="List users", parents=[fp])
    p = sub.add_parser("user", help="Get a single user's detail", parents=[fp])
    p.add_argument("id", help="User ID")
    sub.add_parser("workspace", help="Get workspace info", parents=[fp])

    # --- Compliance ---
    p = sub.add_parser("compliance", help="Get compliance overview", parents=[fp])
    p.add_argument("framework", choices=["soc2", "nis2", "iso27001", "cis", "cis_aws"])

    # --- Research ---
    p = sub.add_parser("cve", help="Get CVE details", parents=[fp])
    p.add_argument("id", help="CVE ID (e.g. CVE-2024-1234)")

    p = sub.add_parser("malware", help="Search malware packages", parents=[fp])
    p.add_argument("--search", help="Search term")
    p.add_argument("--ecosystem", help="Filter by ecosystem (npm, pypi, etc.)")
    p.add_argument("--page", type=int, default=0)
    p.add_argument("--per-page", type=int, default=20, dest="per_page")

    p = sub.add_parser(
        "changelog", help="Get changelog summary for a package upgrade", parents=[fp]
    )
    p.add_argument("package", help="Package name")
    p.add_argument("from_version", help="From version")
    p.add_argument("to_version", help="To version")
    p.add_argument("language", help="Language (JS, PY, etc.)")

    p = sub.add_parser("licenses", help="List & search SBOM licenses", parents=[fp])
    p.add_argument("--search", help="Search term")
    p.add_argument("--page", type=int, default=0)
    p.add_argument("--per-page", type=int, default=20, dest="per_page")

    # --- Reports ---
    sub.add_parser("activity-log", help="List activity log", parents=[fp])
    sub.add_parser("pr-checks", help="List PR checks / CI scans", parents=[fp])
    sub.add_parser("sast-rules", help="List SAST rules", parents=[fp])
    sub.add_parser("iac-rules", help="List IaC rules", parents=[fp])
    sub.add_parser("mobile-rules", help="List Mobile rules", parents=[fp])

    p = sub.add_parser("report-pdf", help="Export PDF report", parents=[fp])
    p.add_argument("sections", help="Comma-separated sections to include")
    p.add_argument("--team", type=int, help="Filter by team ID")
    p.add_argument("--repo-id", type=int, dest="repo_id", help="Filter by repo ID")

    # --- VMs ---
    sub.add_parser("vms", help="List virtual machines", parents=[fp])

    # --- Webhooks ---
    sub.add_parser("webhooks", help="List webhooks", parents=[fp])
    p = sub.add_parser("add-webhook", help="Add webhook", parents=[fp])
    p.add_argument("config", help="JSON config for webhook")
    p = sub.add_parser("remove-webhook", help="Remove webhook", parents=[fp])
    p.add_argument("id", type=int)

    # --- Generic escape hatch + discovery ---
    p = sub.add_parser("raw", help="Call any public-v1 endpoint directly", parents=[fp])
    p.add_argument("method", help="HTTP method: GET, POST, PUT, DELETE")
    p.add_argument(
        "path",
        help="Path relative to /public/v1, e.g. /pentests/issues/123/attackAnalysis",
    )
    p.add_argument(
        "--query", "-q", action="append", help="Query param key=value (repeatable)"
    )
    p.add_argument("--body", help="JSON request body for POST/PUT/DELETE")

    p = sub.add_parser(
        "spec",
        help="List API endpoints (--search to filter, --json for full OpenAPI)",
        parents=[fp],
    )
    p.add_argument("--search", help="Filter endpoints by path/summary substring")
    p.add_argument("--json", action="store_true", help="Dump the full OpenAPI document")

    args = parser.parse_args()
    fields = [f.strip() for f in args.fields.split(",")] if args.fields else None

    dispatch: dict[str, Any] = {
        "counts": cmd_counts,
        "groups": cmd_groups,
        "group": cmd_group,
        "issues": cmd_issues,
        "issue": cmd_issue,
        "issue-bulk": cmd_issue_bulk,
        "reachability": cmd_reachability,
        "pentest": cmd_pentest,
        "attack": cmd_attack,
        "pentest-assessment": cmd_pentest_assessment,
        "ignore": cmd_ignore,
        "unignore": cmd_unignore,
        "snooze": cmd_snooze,
        "unsnooze": cmd_unsnooze,
        "adjust-severity": cmd_adjust_severity,
        "ignore-group": cmd_ignore_group,
        "unignore-group": cmd_unignore_group,
        "snooze-group": cmd_snooze_group,
        "unsnooze-group": cmd_unsnooze_group,
        "adjust-group-severity": cmd_adjust_group_severity,
        "note": cmd_note,
        "group-tasks": cmd_group_tasks,
        "group-notes": cmd_group_notes,
        "repos": cmd_repos,
        "repo": cmd_repo,
        "scan-repo": cmd_scan_repo,
        "sbom": cmd_sbom,
        "containers": cmd_containers,
        "container": cmd_container,
        "scan-container": cmd_scan_container,
        "domains": cmd_domains,
        "scan-domain": cmd_scan_domain,
        "clouds": cmd_clouds,
        "teams": cmd_teams,
        "users": cmd_users,
        "user": cmd_user,
        "workspace": cmd_workspace,
        "compliance": cmd_compliance,
        "cve": cmd_cve,
        "malware": cmd_malware,
        "changelog": cmd_changelog,
        "licenses": cmd_licenses,
        "activity-log": cmd_activity_log,
        "pr-checks": cmd_pr_checks,
        "sast-rules": cmd_sast_rules,
        "iac-rules": cmd_iac_rules,
        "mobile-rules": cmd_mobile_rules,
        "report-pdf": cmd_report_pdf,
        "vms": cmd_vms,
        "webhooks": cmd_webhooks,
        "add-webhook": cmd_add_webhook,
        "remove-webhook": cmd_remove_webhook,
        "raw": cmd_raw,
        "spec": cmd_spec,
    }
    data = dispatch[args.command](args)
    print(fmt(data, fields))


if __name__ == "__main__":
    main()
