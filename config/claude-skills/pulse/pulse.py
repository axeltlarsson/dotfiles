"""Gather GitHub notifications, PR activity, Linear updates and MWAA DAG health into a markdown digest for /pulse."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote

import boto3

ORG = "Jojnts"
LINEAR_TEAMS = {"DAT": "Data", "PROD": "Product", "INF": "Infrastructure"}
# profile:region pairs; every MWAA environment found in each is checked
MWAA_ACCOUNTS = [
    tuple(a.split(":", 1))
    for a in os.environ.get(
        "PULSE_MWAA_ACCOUNTS", "legacy:eu-central-1,shared_admin:eu-west-1"
    ).split(",")
]
LONG_RUNNING = timedelta(hours=6)
LOG_DAG_CAP = 10
LOG_LINE = re.compile(r"error|exception|traceback|failed|killed|timeout", re.IGNORECASE)
REASON_ORDER = [
    "review_requested",
    "mention",
    "team_mention",
    "assign",
    "author",
    "comment",
]
NOISE_REASONS = {"subscribed", "state_change", "ci_activity"}
BOT_LOGINS = {
    "copilot-pull-request-reviewer",
    "aikido-pr-checks",
    "linear",
    "github-actions",
    "renovate",
    "dependabot",
}

PR_BASE = """
  number title url isDraft state createdAt mergedAt closedAt
  author { login __typename }
  repository { name nameWithOwner }
"""
PR_DETAIL = (
    PR_BASE
    + """
  reviewDecision
  commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
  latestReviews(first: 20) { nodes { author { login } state } }
  reviews(last: 30) { nodes { author { login __typename } state submittedAt } }
  comments(last: 30) { nodes { author { login __typename } createdAt } }
"""
)


def search_query(fields: str) -> str:
    return """
query($q: String!, $after: String) {
  search(query: $q, type: ISSUE, first: 100, after: $after) {
    nodes { ... on PullRequest { FIELDS } }
    pageInfo { hasNextPage endCursor }
  }
}
""".replace("FIELDS", fields)


def run(cmd: list[str]) -> str:
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        sys.exit(f"{' '.join(cmd[:3])} failed: {res.stderr.strip()}")
    return res.stdout


def graphql(query: str, **variables: str) -> dict[str, Any]:
    cmd = ["gh", "api", "graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        cmd += ["-f", f"{k}={v}"]
    return json.loads(run(cmd))["data"]


def default_since(now: datetime) -> datetime:
    """Last workday: 24h back, or Friday 00:00 when run on Mon/Sat/Sun."""
    local = now.astimezone()
    days_back = {0: 3, 5: 1, 6: 2}.get(local.weekday())
    if days_back is None:
        return now - timedelta(hours=24)
    start = (local - timedelta(days=days_back)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return start.astimezone(timezone.utc)


def parse_since(spec: str, now: datetime) -> datetime:
    m = re.fullmatch(r"(\d+)([hdw])", spec.strip())
    if m:
        n, unit = int(m.group(1)), m.group(2)
        return (
            now
            - {
                "h": timedelta(hours=n),
                "d": timedelta(days=n),
                "w": timedelta(weeks=n),
            }[unit]
        )
    dt = datetime.fromisoformat(spec.replace("Z", "+00:00"))
    return (dt if dt.tzinfo else dt.astimezone()).astimezone(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def is_bot(author: dict[str, Any] | None) -> bool:
    if not author:
        return True
    login = author.get("login") or ""
    return (
        author.get("__typename") == "Bot"
        or login in BOT_LOGINS
        or login.endswith("[bot]")
    )


def pr_link(pr: dict[str, Any]) -> str:
    return f"[{pr['repository']['name']}#{pr['number']} {pr['title']}]({pr['url']})"


def human_activity(pr: dict[str, Any], me: str, since: str) -> list[str]:
    humans: list[str] = []
    for r in pr["reviews"]["nodes"]:
        if (
            (r["submittedAt"] or "") >= since
            and not is_bot(r["author"])
            and r["author"]["login"] != me
        ):
            humans.append(f"{r['author']['login']}:{r['state']}")
    for c in pr["comments"]["nodes"]:
        if (
            c["createdAt"] >= since
            and not is_bot(c["author"])
            and c["author"]["login"] != me
        ):
            humans.append(f"{c['author']['login']}:comment")
    return list(dict.fromkeys(humans))


def needs_attention(pr: dict[str, Any], me: str, since: str) -> bool:
    commits = pr["commits"]["nodes"]
    rollup = commits[0]["commit"]["statusCheckRollup"] if commits else None
    return (
        bool(human_activity(pr, me, since))
        or pr["reviewDecision"] in ("APPROVED", "CHANGES_REQUESTED")
        or (rollup or {}).get("state") == "FAILURE"
    )


def pr_line(pr: dict[str, Any], me: str, since: str) -> str:
    """One digest line; detail fields are only present when fetched with PR_DETAIL."""
    author = pr.get("author") or {}
    parts = [
        pr_link(pr),
        f"by {author.get('login', '?')}" + (" (bot)" if is_bot(author) else ""),
    ]
    state = pr["state"] + (" draft" if pr["isDraft"] else "")
    parts.append(state)
    if "reviewDecision" in pr:
        commits = pr["commits"]["nodes"]
        rollup = commits[0]["commit"]["statusCheckRollup"] if commits else None
        parts.append(f"review {pr['reviewDecision'] or '-'}")
        parts.append(f"checks {rollup['state'] if rollup else '-'}")
        mine = [
            r["state"]
            for r in pr["latestReviews"]["nodes"]
            if (r["author"] or {}).get("login") == me
        ]
        if mine:
            parts.append(f"my review {mine[-1]}")
        humans = human_activity(pr, me, since)
        parts.append("human activity: " + (", ".join(humans) if humans else "none"))
    return "- " + " | ".join(parts)


def search_prs(q: str, fields: str, cap: int = 300) -> list[dict[str, Any]]:
    prs: list[dict[str, Any]] = []
    after: str | None = None
    query = search_query(fields)
    while len(prs) < cap:
        data = graphql(query, q=q, **({"after": after} if after else {}))["search"]
        prs += [n for n in data["nodes"] if n]
        if not data["pageInfo"]["hasNextPage"]:
            break
        after = data["pageInfo"]["endCursor"]
    return prs


def notifications() -> list[dict[str, Any]]:
    jq = ".[] | {repo: .repository.full_name, reason, type: .subject.type, title: .subject.title, api_url: .subject.url}"
    out = run(["gh", "api", "notifications?per_page=50", "--paginate", "--jq", jq])
    return [json.loads(line) for line in out.splitlines() if line.strip()]


def fetch_prs(
    refs: list[tuple[str, str, int]],
) -> dict[tuple[str, int], dict[str, Any]]:
    """Batch-fetch PR details for (owner, repo, number) via aliased GraphQL."""
    out: dict[tuple[str, int], dict[str, Any]] = {}
    for start in range(0, len(refs), 40):
        chunk = refs[start : start + 40]
        body = "\n".join(
            f'p{i}: repository(owner: "{o}", name: "{r}") {{ pullRequest(number: {n}) {{ ...pr }} }}'
            for i, (o, r, n) in enumerate(chunk)
        )
        query = f"query {{ {body} }}\nfragment pr on PullRequest {{ {PR_DETAIL} }}"
        data = graphql(query)
        for i, (o, r, n) in enumerate(chunk):
            pr = (data.get(f"p{i}") or {}).get("pullRequest")
            if pr:
                out[(f"{o}/{r}", n)] = pr
    return out


def html_url(api_url: str | None, repo: str) -> str:
    if not api_url:
        return f"https://github.com/{repo}"
    url = api_url.replace(
        "https://api.github.com/repos/", "https://github.com/"
    ).replace("/commits/", "/commit/")
    return re.sub(r"/pulls/(\d+)$", r"/pull/\1", url)


def linear_team(team: str, since: str) -> list[dict[str, Any]] | str:
    fields = "identifier,title,url,state.name,assignee.name"
    cmd = [
        "linear",
        "issues",
        "--team",
        team,
        "--updated-since",
        since,
        "--all",
        "--fields",
        fields,
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return json.loads(res.stdout) if res.returncode == 0 else res.stderr.strip()[-300:]


def parse_ts(ts: str | None) -> datetime | None:
    return datetime.fromisoformat(ts) if ts else None


class Airflow:
    """Airflow REST API (v1) through MWAA invoke_rest_api."""

    def __init__(self, client: Any, name: str) -> None:
        self.client = client
        self.name = name
        env = client.get_environment(Name=name)["Environment"]
        self.ui = f"https://{env['WebserverUrl']}"

    def get(self, path: str, **params: Any) -> Any:
        res = self.client.invoke_rest_api(
            Name=self.name, Path=path, Method="GET", QueryParameters=params
        )
        return res["RestApiResponse"]

    def paginate(self, path: str, key: str, **params: Any) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        while True:
            page = self.get(path, limit=100, offset=len(items), **params)
            items += page[key]
            if not page[key] or len(items) >= page["total_entries"]:
                return items

    def failed_tasks(self, run: dict[str, Any]) -> list[str]:
        base = f"/dags/{run['dag_id']}/dagRuns/{quote(run['dag_run_id'], safe='')}/taskInstances"
        lines = []
        for ti in self.get(base, state="failed")["task_instances"]:
            mapped = ti.get("map_index", -1)
            label = ti["task_id"] + (f"[{mapped}]" if mapped >= 0 else "")
            lines.append(f"  - task {label} (try {ti['try_number']})")
            try:
                log = self.get(
                    f"{base}/{ti['task_id']}/logs/{max(ti['try_number'], 1)}",
                    full_content=True,
                    **({"map_index": mapped} if mapped >= 0 else {}),
                )
                content = log.get("content", "") if isinstance(log, dict) else str(log)
                hits = [
                    ln.strip() for ln in content.splitlines() if LOG_LINE.search(ln)
                ]
                lines += [f"    > {ln[:200]}" for ln in hits[-6:]]
            except Exception as e:  # noqa: BLE001
                lines.append(f"    > log unavailable: {str(e)[:150]}")
        return lines


def dag_issues(
    dag: dict[str, Any], runs: list[dict[str, Any]], now: datetime
) -> list[str]:
    issues = []
    failed = [r for r in runs if r["state"] == "failed"]
    if failed:
        issues.append(f"{len(failed)}/{len(runs)} runs failed")
    for r in runs:
        start = parse_ts(r.get("start_date"))
        if r["state"] == "running" and start and now - start > LONG_RUNNING:
            issues.append(f"running for {(now - start).total_seconds() / 3600:.0f}h")
    due = parse_ts(dag.get("next_dagrun_create_after"))
    if not dag["is_paused"] and due and now - due > timedelta(hours=1):
        issues.append(f"overdue: next run was due {iso(due)}")
    return issues


def mwaa_section(since: str, now: datetime) -> list[str]:
    lines: list[str] = []
    for profile, region in MWAA_ACCOUNTS:
        try:
            session = boto3.Session(profile_name=profile, region_name=region)
            client = session.client("mwaa")
            names = client.list_environments()["Environments"]
        except Exception as e:  # noqa: BLE001
            lines += [
                f"## Airflow ({profile} {region}): FETCH FAILED: {str(e)[-300:]}",
                f"(if the SSO token expired: `aws sso login --profile {profile}`, then rerun `pulse gather`)",
                "",
            ]
            continue
        for name in names:
            lines += env_section(client, name, f"{profile} {region}", since, now)
    return lines


def env_section(
    client: Any, name: str, where: str, since: str, now: datetime
) -> list[str]:
    head = f"## Airflow DAGs: {name} ({where})"
    try:
        af = Airflow(client, name)
        dags = af.paginate("/dags", "dags", only_active=True)
        runs = af.paginate("/dags/~/dagRuns", "dag_runs", start_date_gte=since)
        runs += af.paginate("/dags/~/dagRuns", "dag_runs", state="running")
        import_errors = af.paginate("/importErrors", "import_errors")
    except Exception as e:  # noqa: BLE001
        return [f"{head}: FETCH FAILED: {str(e)[-300:]}", ""]

    by_dag: dict[str, dict[str, dict[str, Any]]] = {}
    for r in runs:
        by_dag.setdefault(r["dag_id"], {})[r["dag_run_id"]] = r
    lines = [f"{head} since {since}", ""]
    if import_errors:
        lines.append(f"### Import errors ({len(import_errors)})")
        for ie in import_errors:
            first = (ie.get("stack_trace") or "").strip().splitlines()[-1:] or [""]
            lines.append(f"- {ie['filename']}: {first[0][:200]}")
        lines.append("")

    broken, recovered, healthy = [], [], []
    logged = 0
    for dag in sorted(dags, key=lambda d: d["dag_id"]):
        if dag["is_paused"]:
            continue
        dag_runs = sorted(
            by_dag.get(dag["dag_id"], {}).values(),
            key=lambda r: r.get("start_date") or r.get("execution_date") or "",
        )
        issues = dag_issues(dag, dag_runs, now)
        done = [r for r in dag_runs if r["state"] in ("success", "failed")]
        latest = done[-1]["state"] if done else "no finished runs in window"
        if not issues:
            healthy.append(dag["dag_id"])
            continue
        line = (
            f"- [{dag['dag_id']}]({af.ui}/dags/{dag['dag_id']}/grid) | latest {latest}"
            f" | {dag.get('timetable_description') or '-'} | " + "; ".join(issues)
        )
        if latest == "success" and all(i.endswith("runs failed") for i in issues):
            recovered.append(line)
            continue
        broken.append(line)
        if latest == "failed" and logged < LOG_DAG_CAP:
            logged += 1
            broken += af.failed_tasks(done[-1])

    paused = sum(d["is_paused"] for d in dags)
    lines += [
        "### Need a glance (latest run failed/running long, or overdue)",
        *(broken or ["- none"]),
        "",
        "### Recovered (failed in window, latest run succeeded)",
        *(recovered or ["- none"]),
        "",
        f"### Healthy ({len(healthy)}): " + ", ".join(healthy),
        f"### Paused: {paused}",
        "",
    ]
    return lines


def notification_section(
    notifs: list[dict[str, Any]], prs: dict[tuple[str, int], Any], me: str, since: str
) -> list[str]:
    lines = [f"## Unread notifications ({len(notifs)})", ""]
    rank = {r: i for i, r in enumerate(REASON_ORDER)}
    signal = [n for n in notifs if n["reason"] not in NOISE_REASONS]
    noise = len(notifs) - len(signal)
    for reason in sorted(
        {n["reason"] for n in signal}, key=lambda r: rank.get(r, len(rank))
    ):
        lines.append(f"### {reason}")
        for n in (n for n in signal if n["reason"] == reason):
            m = re.search(r"/pulls/(\d+)$", n["api_url"] or "")
            pr = prs.get((n["repo"], int(m.group(1)))) if m else None
            if pr:
                lines.append(pr_line(pr, me, since))
            else:
                lines.append(
                    f"- [{n['repo'].split('/')[-1]}: {n['title']}]({html_url(n['api_url'], n['repo'])}) | {n['type']}"
                )
        lines.append("")
    lines.append(
        f"({noise} subscribed/state_change notifications omitted; their PRs appear under org PRs)"
    )
    return lines


def org_section(prs: list[dict[str, Any]], since: str, me: str) -> list[str]:
    groups: dict[str, list[dict[str, Any]]] = {
        "Merged": [],
        "Opened": [],
        "Closed unmerged": [],
        "Other activity": [],
    }
    for pr in prs:
        if pr["mergedAt"] and pr["mergedAt"] >= since:
            groups["Merged"].append(pr)
        elif pr["state"] == "CLOSED" and (pr["closedAt"] or "") >= since:
            groups["Closed unmerged"].append(pr)
        elif pr["createdAt"] >= since:
            groups["Opened"].append(pr)
        else:
            groups["Other activity"].append(pr)
    lines = [f"## Org PRs updated since {since}", ""]
    for name, items in groups.items():
        lines.append(f"### {name} ({len(items)})")
        items.sort(key=lambda p: (p["repository"]["name"], p["number"]))
        lines += [pr_line(p, me, since) for p in items]
        lines.append("")
    return lines


def cmd_gather(args: argparse.Namespace) -> None:
    now = datetime.now(timezone.utc)
    since = iso(parse_since(args.since, now) if args.since else default_since(now))
    pr_detail_q = f"is:pr is:open archived:false org:{ORG}"
    with ThreadPoolExecutor(max_workers=8) as pool:
        f_me = pool.submit(lambda: graphql("{ viewer { login } }")["viewer"]["login"])
        f_notifs = pool.submit(notifications)
        f_rr = pool.submit(search_prs, f"{pr_detail_q} review-requested:@me", PR_DETAIL)
        f_mine = pool.submit(search_prs, f"{pr_detail_q} author:@me", PR_DETAIL)
        f_org = pool.submit(search_prs, f"org:{ORG} is:pr updated:>={since}", PR_BASE)
        f_lin = {t: pool.submit(linear_team, t, since) for t in LINEAR_TEAMS}
        f_mwaa = pool.submit(mwaa_section, since, now)
        notifs = f_notifs.result()
        refs = {
            (n["repo"].split("/")[0], n["repo"].split("/")[1], int(m.group(1)))
            for n in notifs
            if n["reason"] not in NOISE_REASONS
            and (m := re.search(r"/pulls/(\d+)$", n["api_url"] or ""))
        }
        f_notif_prs = pool.submit(fetch_prs, sorted(refs))
        me = f_me.result()

    lines = [
        "# Pulse digest",
        "",
        f"- me: {me}",
        f"- since: {since}",
        f"- fetched_at: {iso(now)}  (pass to `pulse mark-read --before`)",
        "",
    ]
    lines += notification_section(notifs, f_notif_prs.result(), me, since) + [""]
    rr = f_rr.result()
    lines += (
        [f"## Open PRs awaiting my review ({len(rr)})", ""]
        + [pr_line(p, me, since) for p in rr]
        + [""]
    )
    mine = sorted(
        f_mine.result(),
        key=lambda p: (p["isDraft"], p["repository"]["name"], p["number"]),
    )
    lines += (
        [
            f"## My open PRs ({len(mine)}; ATTENTION = human activity, a decision or failing checks)",
            "",
        ]
        + [
            pr_line(p, me, since)
            + (" | ATTENTION" if needs_attention(p, me, since) else "")
            for p in mine
        ]
        + [""]
    )
    lines += org_section(f_org.result(), since, me)
    for team, name in LINEAR_TEAMS.items():
        issues = f_lin[team].result()
        if isinstance(issues, str):
            lines += [f"## Linear {name} ({team}): FETCH FAILED: {issues}", ""]
            continue
        lines += [
            f"## Linear {name} ({team}) updated since {since} ({len(issues)})",
            "",
        ]
        for i in sorted(issues, key=lambda i: i.get("state.name") or ""):
            lines.append(
                f"- [{i['identifier']} {i['title']}]({i['url']}) | {i.get('state.name')} | {i.get('assignee.name') or 'unassigned'}"
            )
        lines.append("")
    lines += f_mwaa.result()

    path = Path(tempfile.gettempdir()) / f"pulse-{now.strftime('%Y%m%dT%H%M%S')}.md"
    path.write_text("\n".join(lines))
    print(f"Digest written to {path} ({len(lines)} lines). fetched_at={iso(now)}")


def cmd_mark_read(args: argparse.Namespace) -> None:
    run(
        [
            "gh",
            "api",
            "-X",
            "PUT",
            "notifications",
            "-f",
            f"last_read_at={args.before}",
            "-F",
            "read=true",
        ]
    )
    print(f"Marked notifications up to {args.before} as read")


def main() -> None:
    parser = argparse.ArgumentParser(prog="pulse", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    g = sub.add_parser(
        "gather",
        help="Write a markdown digest of GitHub + Linear activity and print its path",
    )
    g.add_argument(
        "--since",
        help="Window start for org PRs/Linear: Nh/Nd/Nw or ISO date (default: last workday)",
    )
    g.set_defaults(func=cmd_gather)
    m = sub.add_parser(
        "mark-read", help="Mark GitHub notifications read up to a timestamp"
    )
    m.add_argument(
        "--before", required=True, help="ISO timestamp, normally fetched_at from gather"
    )
    m.set_defaults(func=cmd_mark_read)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
