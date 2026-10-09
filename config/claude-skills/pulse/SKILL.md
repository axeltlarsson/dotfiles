---
name: pulse
description: Morning org pulse - summarise all unread GitHub notifications, org-wide PR activity (Jojnts) and Linear activity for the Data, Product and Infrastructure teams, then mark the notifications read. Use when the user runs /pulse or asks what is going on in the org / for their morning PR and Linear summary.
allowed-tools: Bash(pulse *), Read
---

# Pulse

A read-through summary of what is happening in the org, replacing a manual pass over github.com/notifications. Output goes to the terminal only. It is for reading, not pasting.

## Steps (exactly three tool calls)

1. Run `pulse gather` as a **bare command**. Add `--since <arg>` only if the user passed an argument (e.g. `3d`, `12h`, `2026-10-01`). No redirects, pipes, `;`, `&&` or `echo`: `pulse` is excluded from the sandbox only when it is the whole command. It prints the path of a markdown digest and `fetched_at`.
2. `Read` the digest file. It already holds everything: links, PR state, review decision, checks, your own review, and human (non-bot) activity in the window. **Don't run `jq`, `gh` or `linear` to explore further.**
3. Run `pulse mark-read --before <fetched_at>` as a bare command, then write the report. Don't ask first; the user wants this. Skip it only if `gather` failed.

Finish with one line saying how many notifications were marked read.

## Report layout

Keep it terse and scannable. Use `##` headings and skip any empty section.

**Every PR and issue mention must be a markdown link copied from the digest**, also inside grouped or inline mentions. Write `[jojnts-service#9983](url)`, never a bare `#9983`. Shortening the link text to `repo#N` in prose is fine. Write Linear issues the same way, e.g. `[DAT-123](url)`.

1. **Needs you**: review requests that are still open and that you haven't reviewed, @mentions, human activity on your PRs, your PRs with `CHANGES_REQUESTED` or failing checks, and your approved PRs that are ready to merge. Put requests that are already handled (merged, or you already reviewed them) in one short trailing line.
2. **My pipeline**: every open PR of yours, drafts included, as a reminder of what's in flight. Keep it compact: group by repo or theme, one line per PR or series, and mark drafts. Leave the details to the PRs flagged `ATTENTION`, which also belong under **Needs you**.
3. **Shipped**: merged PRs grouped by repo, each with the author and a few-word gist. Collapse bot PRs into a count.
4. **In flight**: opened and still-active PRs from others (yours are under My pipeline). Group them by theme or author where a series belongs together (e.g. a run of PRs for the same Linear issue). Collapse drafts and bots. Mention closed-unmerged PRs only when they mean something, e.g. a series that was folded into a new PR.
5. **Linear**: per team (Data, Product, Infrastructure): done, started or in review, and new or triage items worth knowing about. Give a quiet team one line.
6. **Themes**: 2–3 bullets on what the org is working on, tying PRs to Linear issues where the IDs match.

Never include PHI.

$ARGUMENTS
