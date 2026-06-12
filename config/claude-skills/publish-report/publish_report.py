"""Publish an HTML report to the Joint Academy reports site and return a shareable link.

Decoupled upload half of the old notebook `reports-uploader` (no nbconvert, no Jupyter).
Reuses the EXISTING deployed infra:
  - uploads to the `reports.eu.jastage.io` S3 bucket
  - served by a CloudFront distribution gated by Cognito OAuth (@jointacademy.com staff)
  - assumes the dedicated reports-upload IAM role, then invalidates the CloudFront path

Config + credentials are read from the macOS login Keychain (one generic-password item
per value, under the service name `publish-report`), unless already present in the env.
Required values (same names the old tool used):
  REPORTS_ROLE_ARN          IAM role to assume for upload
  REPORTS_BUCKET_NAME       target S3 bucket
  REPORTS_BASE_URL          public base, e.g. https://reports.eu.jastage.io
  REPORTS_DISTRIBUTION_ID   CloudFront distribution id (for cache invalidation)
  AWS_ACCESS_KEY_ID         upload user's key (used to assume the role)
  AWS_SECRET_ACCESS_KEY     upload user's secret

One-time setup (see SKILL.md) stores each value:
  security add-generic-password -U -s publish-report -a REPORTS_ROLE_ARN -w
"""

from __future__ import annotations

import argparse
import mimetypes
import os
import subprocess
import sys
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

KEYCHAIN_SERVICE = os.environ.get("REPORTS_KEYCHAIN_SERVICE", "publish-report")
REQUIRED = [
    "REPORTS_ROLE_ARN",
    "REPORTS_BUCKET_NAME",
    "REPORTS_BASE_URL",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
]
OPTIONAL = ["REPORTS_DISTRIBUTION_ID"]


def load_from_keychain(service: str) -> list[str]:
    """Populate any missing config from the login Keychain. Returns the names loaded."""
    loaded = []
    for name in REQUIRED + OPTIONAL:
        if os.environ.get(name):
            continue
        result = subprocess.run(
            ["security", "find-generic-password", "-s", service, "-a", name, "-w"],
            capture_output=True,
            text=True,
        )
        value = result.stdout.rstrip("\n")
        if result.returncode == 0 and value:
            os.environ[name] = value
            loaded.append(name)
    return loaded


def assume_session(role_arn: str) -> boto3.Session:
    creds = boto3.client("sts").assume_role(
        RoleArn=role_arn, RoleSessionName="publish-report"
    )["Credentials"]
    return boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
    )


def upload(session: boto3.Session, file: Path, bucket: str, key: str) -> None:
    extra = {
        "CacheControl": "no-cache, must-revalidate",
        "ContentDisposition": "inline",
    }
    ctype = mimetypes.guess_type(str(file))[0]
    if ctype:
        extra["ContentType"] = ctype
    session.client("s3").upload_file(str(file), bucket, key, ExtraArgs=extra)


def invalidate(session: boto3.Session, distribution_id: str, key: str) -> None:
    session.client("cloudfront").create_invalidation(
        DistributionId=distribution_id,
        InvalidationBatch={
            "Paths": {"Quantity": 1, "Items": [f"/{key}"]},
            "CallerReference": f"publish-report-{key}",
        },
    )


def main() -> int:
    p = argparse.ArgumentParser(
        description="Publish an HTML report and get a shareable link."
    )
    p.add_argument("file", type=Path, help="path to the .html report")
    p.add_argument("--prefix", default="", help="key prefix, e.g. 'us_payer_reports'")
    p.add_argument(
        "--name", default="", help="override the uploaded filename (without .html)"
    )
    p.add_argument(
        "--no-invalidate", action="store_true", help="skip CloudFront invalidation"
    )
    args = p.parse_args()

    if not args.file.is_file():
        print(f"no such file: {args.file}", file=sys.stderr)
        return 1
    if args.file.suffix.lower() not in {".html", ".htm"}:
        print(f"expected an .html file, got {args.file.suffix}", file=sys.stderr)
        return 1

    load_from_keychain(KEYCHAIN_SERVICE)
    missing = [n for n in REQUIRED if not os.environ.get(n)]
    if missing:
        print(
            f"missing config: {', '.join(missing)}\n"
            f"Store them in the login Keychain under service {KEYCHAIN_SERVICE!r} "
            "(see SKILL.md), or export them in the env.",
            file=sys.stderr,
        )
        return 2

    bucket = os.environ["REPORTS_BUCKET_NAME"]
    base_url = os.environ["REPORTS_BASE_URL"].rstrip("/")
    distribution_id = os.environ.get("REPORTS_DISTRIBUTION_ID")

    filename = (args.name or args.file.stem) + ".html"
    key = "/".join(part for part in (args.prefix.strip("/"), filename) if part)

    try:
        session = assume_session(os.environ["REPORTS_ROLE_ARN"])
        upload(session, args.file, bucket, key)
        if distribution_id and not args.no_invalidate:
            invalidate(session, distribution_id, key)
    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1

    print(f"{base_url}/{key}")
    print(
        "\n  Cognito-gated — @jointacademy.com staff sign in to view.", file=sys.stderr
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
