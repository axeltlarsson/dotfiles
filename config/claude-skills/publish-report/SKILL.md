---
name: publish-report
description: Publish an HTML report to the central Joint Academy reports site (reports.eu.jastage.io) and return a shareable, Cognito-gated link. Use when you have produced an HTML report (cost report, infra audit, analysis, etc.) and the user wants to share it with colleagues instead of it sitting as a local file.
allowed-tools: Bash(publish-report *), Bash(security find-generic-password *)
---

# Publish report

Turn a local HTML report into a shareable URL on `reports.eu.jastage.io`. This is the
**file → link** half lifted out of the old notebook `reports-uploader` — no nbconvert, no
Jupyter, no conversion. If you have a `.ipynb`, export it to HTML first.

## Use

```bash
publish-report cost-report.html --prefix cost
```

Prints the URL on stdout (clean, copyable). Relay it to the user. Reports are served
behind CloudFront + Cognito OAuth, so anyone with an `@jointacademy.com` account can open
the link after signing in — no further sharing setup needed.

Flags: `--prefix <path>` (e.g. `us_payer_reports`), `--name <stem>` (override filename),
`--no-invalidate` (skip CloudFront cache invalidation).

## How it works (reuses existing infra — no new infra)

1. Loads config + creds from the macOS login Keychain (or the env, if already set):
   `REPORTS_ROLE_ARN`, `REPORTS_BUCKET_NAME`, `REPORTS_BASE_URL`,
   `REPORTS_DISTRIBUTION_ID`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
2. Assumes the dedicated `reports-upload` IAM role.
3. Uploads the HTML to the reports S3 bucket (`text/html`, `inline`).
4. Invalidates the CloudFront path so the new version shows immediately.
5. Prints `https://reports.eu.jastage.io/<prefix>/<file>.html`.

## One-time credential setup (Keychain)

`op` (1Password CLI) can't be used here because Claude Code runs inside **tmux**, and
macOS 1Password desktop-app integration refuses tmux-parented processes. So creds live in
the login Keychain instead. Store each value once (the `-w` with no argument prompts so
secrets stay out of shell history):

```bash
for k in REPORTS_ROLE_ARN REPORTS_BUCKET_NAME REPORTS_BASE_URL \
         REPORTS_DISTRIBUTION_ID AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  security add-generic-password -U -s publish-report -a "$k" -w
done
```

The values are the same ones from the "data reports uploader" 1Password item / the old
`.env`. Override the service name with `REPORTS_KEYCHAIN_SERVICE`.

## Notes

- Reports should be **self-contained** (inline CSS/JS; external refs only to public CDNs).
  Relative `src=`/`href=` to local files will 404 once uploaded.
- The reports app lives in the **eu-stage** account; these long-lived upload-user keys are
  independent of the SSO profiles in `platform-infrastructure/aws_config` (no eu-stage one).
- Access is staff-only by design. No built-in no-login / external-share path; that would be
  a separate CloudFront-signed-URL addition.
