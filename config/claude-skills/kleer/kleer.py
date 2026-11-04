"""Kleer (PE Accounting) expense CLI: match receipts to card purchases, file them,
audit the bookkeeping fields, and submit for attest.

Every mutating subcommand is two-phase: it reports first and only acts with --apply.
"""

import argparse
import datetime
import json
import os
import pathlib
import re
import subprocess
import sys
from collections import defaultdict

import httpx

COMPANY = 4483  # Arthro Therapeutics AB
ENV_FILE = pathlib.Path.home() / "work" / ".env"
TOKEN_VAR = "KLEER_PERSONAL_ACCESS_TOKEN"
STATE = pathlib.Path(
    os.environ.get("KLEER_STATE_DIR", pathlib.Path.home() / ".cache" / "kleer")
)

DEPARTMENT_ENGINEERING = 2711922
DATE_WINDOW = 6  # days between a purchase and its receipt's own registration date

# vendor substring -> expense-type id. Each type also carries a Tech & Dev-kategori
# entry, read at runtime from expense/entry/form rather than hardcoded here.
EXPENSE_TYPE = {
    "openai": 139095,  # Developer Tooling
    "anthropic": 139095,
    "circleci": 139095,
    "github": 139095,
    "twilio": 139114,  # Hosting
    "onlydomains": 139114,
    "sentry": 139114,
    "docevent": 139114,
    "google": 149039,  # Other Software / Operations tooling
    "atlassian": 149039,
}

# The supplier's domicile as printed on the receipt, NOT where its EU VAT
# registration sits. Anthropic shows EU VAT IE... but is a San Francisco company.
COUNTRY = {
    "openai": "US",
    "anthropic": "US",
    "circleci": "US",
    "github": "US",
    "twilio": "US",
    "sentry": "US",
    "atlassian": "AU",
    "docevent": "AU",
    "google": "IE",
    "onlydomains": "NZ",
}


def token() -> str:
    """Read just the one variable; never read the whole .env."""
    out = subprocess.run(
        ["rg", "--no-filename", f"^{TOKEN_VAR}=", str(ENV_FILE)],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if not out.strip():
        raise SystemExit(f"{TOKEN_VAR} not found in {ENV_FILE}")
    return out.split("=", 1)[1].strip().strip("\"'")


class Kleer:
    def __init__(self, env: str) -> None:
        host = "api" if env == "prod" else "test-api"
        self.env = env
        self.base = f"https://{host}.kleer.se/v1/company/{COMPANY}"
        # Kleer picks the RESPONSE format from the REQUEST Content-Type, not Accept.
        self.client = httpx.Client(
            headers={"X-Token": token(), "Content-Type": "application/json"},
            timeout=120.0,
            follow_redirects=True,
        )

    def _raw(self, method: str, path: str, **kw) -> bytes:
        r = self.client.request(method, f"{self.base}/{path}", **kw)
        r.raise_for_status()
        # thumbnails are inlined byte arrays and make the payload enormous
        return re.sub(rb'"thumbnail":\s*\[[^\]]*\]', b'"thumbnail":null', r.content)

    def get(self, path: str) -> dict:
        raw = self._raw("GET", path)
        return json.loads(raw) if raw.strip() and raw.strip() != b"{}" else {}

    def rows(self, path: str) -> list[dict]:
        return next((v for v in self.get(path).values() if isinstance(v, list)), [])

    def blob(self, fid: int) -> bytes:
        r = self.client.get(f"{self.base}/expense/file/{fid}")
        data = r.content
        if len(data) < 100 or data[:20].lstrip().startswith(b"<"):
            data = self.client.get(f"{self.base}/expense/file/{fid}/image").content
        return data

    def put_file(self, pdf: pathlib.Path) -> int:
        """The body must be application/pdf, so THIS call answers in XML."""
        r = self.client.put(
            f"{self.base}/expense/file",
            content=pdf.read_bytes(),
            headers={"Content-Type": "application/pdf"},
        )
        r.raise_for_status()
        m = re.search(rb"<id>(\d+)</id>", r.content) or re.search(
            rb'"id"\s*:\s*(\d+)', r.content
        )
        if not m:
            raise SystemExit(
                f"upload of {pdf.name} returned no id: {r.content[:200]!r}"
            )
        return int(m.group(1))

    def write(self, method: str, path: str, payload: dict) -> dict:
        r = self.client.request(method, f"{self.base}/{path}", json=payload)
        try:
            out = r.json()
        except ValueError:
            raise SystemExit(
                f"{path}: unparseable response {r.content[:200]!r}"
            ) from None
        if "message" in out:
            raise SystemExit(f"{path}: {out['message']}")
        return out

    # -- reference data ----------------------------------------------------

    def type_dims(self) -> dict[int, list[int]]:
        """Kleer hangs a default dimension entry off an expense TYPE. The web UI copies
        it onto the entry; an API-created entry does NOT get it, so pass it explicitly."""
        form = self.get("expense/entry/form")
        return {
            t["id"]: [
                d["entry"]["id"]
                for d in t.get("dimensions", {}).get("dimensions", [])
                if d.get("entry")
            ]
            for t in form.get("expense-types", {}).get("expense-types", [])
        }

    def open_files(self) -> list[dict]:
        return self.rows("expense/file/open")

    def open_cards(self) -> list[dict]:
        return self.rows("expense/card-transaction/open?offset=0&limit=200")

    def open_entries(self) -> list[dict]:
        return self.rows("expense/entry/open")


def vendor_of(text: str) -> str | None:
    low = text.lower()
    return next((k for k in EXPENSE_TYPE if k in low), None)


def kr(ore: int) -> str:
    return f"{ore / 100:,.2f}"


def billing_of(card: dict) -> int:
    return card.get("billing-amount") or card.get("amount", 0)


def entry_payload(card: dict, fid: int, type_dims: dict[int, list[int]]) -> dict:
    """A card-linked entry books in SEK at the BILLING amount, rate 1.0. Sending the
    purchase's own USD/EUR figure is refused as a mismatch; omitting it is a
    bare 'Tekniskt fel'. The original currency stays on the transaction."""
    vk = vendor_of(card.get("merchant", ""))
    if vk is None:
        raise SystemExit(
            f"{card.get('merchant')!r}: no expense-type mapping — add it to EXPENSE_TYPE"
        )
    type_id = EXPENSE_TYPE[vk]
    return {
        "expense-file": {"id": fid},
        "company-card": {"id": card["company-card"]["id"]},
        "expense-type": {"id": type_id},
        "date": card["date"][:10],
        "description": card.get("merchant", ""),
        "digital": True,
        "amount": billing_of(card),
        "vat": 0,  # foreign supplier, reverse charge
        "currency-type": "SEK",
        "currency-rate": 1.0,
        "country-code": COUNTRY.get(vk, "US"),
        "dimension-entries": {
            "dimension-entries": [
                {"id": DEPARTMENT_ENGINEERING},
                *({"id": i} for i in type_dims.get(type_id, [])),
            ]
        },
        "card-transaction": {"key": card["key"]},
    }


def rewrite_payload(e: dict, **overrides) -> dict:
    """Rebuild a filed entry's writable body from its readable form, for POST updates."""
    payload = {
        "expense-file": e["expense-file"],
        "company-card": e.get("company-card", {}),
        "expense-type": {"id": e["expense-type"]["id"]},
        "date": e["date"],
        "description": e.get("description", ""),
        "digital": e.get("digital", True),
        "amount": e["amount"],
        "vat": e.get("vat", 0),
        "currency-type": e.get("currency-type", "SEK"),
        "currency-rate": e.get("currency-rate", 1.0),
        "country-code": e.get("country-code"),
        "dimension-entries": {
            "dimension-entries": [
                {"id": d["id"]}
                for d in e.get("dimension-entries", {}).get("dimension-entries", [])
            ]
        },
    }
    if e.get("card-transaction"):
        payload["card-transaction"] = e["card-transaction"]
    return payload | overrides


# -- receipt text ----------------------------------------------------------

SYMBOL = {"$": "USD", "US$": "USD", "€": "EUR", "£": "GBP", "kr": "SEK", "SEK": "SEK"}
PATTERNS = [
    re.compile(r"(US\$|\$|€|£)\s?([\d][\d  ,.]*\d|\d)"),
    re.compile(r"\b(USD|EUR|GBP|SEK)\s?([\d][\d  ,.]*\d|\d)"),
    re.compile(r"([\d][\d  ,.]*\d)\s?(USD|EUR|GBP|SEK|kr)\b"),
    re.compile(r"([\d][\d  ,.]*\d)\s?(US\$|\$|€|£)"),  # "850,19 €"
]


def to_ore(raw: str) -> int | None:
    s = raw.strip().replace(" ", "").replace(" ", "")
    if "," in s and "." in s:
        s = (
            s.replace(",", "")
            if s.rfind(".") > s.rfind(",")
            else s.replace(".", "").replace(",", ".")
        )
    elif "," in s:
        s = s.replace(",", ".") if len(s.split(",")[-1]) == 2 else s.replace(",", "")
    try:
        return round(float(s) * 100)
    except ValueError:
        return None


def amounts_in(text: str) -> set[tuple[int, str]]:
    found: set[tuple[int, str]] = set()
    for pat in PATTERNS:
        for m in pat.finditer(text):
            a, b = m.group(1), m.group(2)
            cur = SYMBOL.get(a) or SYMBOL.get(b) or (a if a.isalpha() else b)
            num = b if a in SYMBOL or not a[0].isdigit() else a
            ore = to_ore(num)
            if ore and ore > 0:
                found.add((ore, cur.upper() if cur else "?"))
    return found


def text_of(k: Kleer, f: dict) -> str:
    cache = STATE / "receipts" / k.env
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / f"{f['id']}_{f.get('filename', 'x')}"
    if not path.exists():
        path.write_bytes(k.blob(f["id"]))
    if path.read_bytes()[:4] != b"%PDF":
        return ""  # an image: needs vision, not pdftotext
    r = subprocess.run(
        ["pdftotext", "-q", str(path), "-"], capture_output=True, check=False
    )
    return r.stdout.decode("utf-8", "replace")


def days_apart(a: str, b: str) -> int:
    try:
        x = datetime.date.fromisoformat(a[:10])
        y = datetime.date.fromisoformat(b[:10])
        return abs((x - y).days)
    except ValueError:
        return 999


def assign(k: Kleer, cards: list[dict], files: list[dict]) -> tuple[dict, dict, list]:
    """1:1 match purchases to receipt files on the ORIGINAL printed amount.

    Billing SEK moves with FX between authorisation and settlement; the vendor's own
    figure does not. Scarcest purchase first, so a unique match claims its file.
    """
    text = {f["id"]: text_of(k, f) for f in files}
    amts = {fid: amounts_in(t) for fid, t in text.items()}
    cand: dict[str, list[int]] = {}
    for c in cards:
        vk = vendor_of(c.get("merchant", ""))
        want = (c.get("amount", 0), (c.get("currency-type") or "").upper())
        cand[c["key"]] = [
            f["id"]
            for f in files
            if want in amts[f["id"]]
            and days_apart(c["date"], f.get("registration-date", "")) <= DATE_WINDOW
            and (vk is None or vk in text[f["id"]].lower())
        ]
    chosen: dict[str, int] = {}
    taken: set[int] = set()
    for key in sorted(cand, key=lambda x: len(cand[x])):
        free = [i for i in cand[key] if i not in taken]
        if len(free) == 1:
            chosen[key] = free[0]
            taken.add(free[0])
    return chosen, cand, [f for f in files if f["id"] not in taken]


# -- subcommands -----------------------------------------------------------


def cmd_status(k: Kleer, args) -> int:
    files, cards, entries = k.open_files(), k.open_cards(), k.open_entries()
    held = [c for c in cards if c.get("reservation")]
    print(f"=== Kleer {k.env} · Arthro Therapeutics AB ===\n")
    print(f"  nya kvitton                : {len(files)}")
    print(f"  kortköp att redovisa       : {len(cards)}  ({len(held)} reservations)")
    print(f"  utlägg att lämna in        : {len(entries)}")
    if entries:
        print(f"  {'':27}  {kr(sum(e['amount'] for e in entries))} SEK")
    if held:
        print("\n  reservations (amount can still move — not filed):")
        for c in held:
            print(
                f"    {c['date']}  {c.get('merchant', '')[:28]:30}"
                f"{kr(c.get('amount', 0)):>12} {c.get('currency-type', '')}"
            )
    return 0


def cmd_audit(k: Kleer, args) -> int:
    """Group entries by what is ACTUALLY on them, never by the expense type's template."""
    sources = ["expense/entry/open"] + [
        f"expense/entry/expense/{n}" for n in args.expense_nr
    ]
    entries = [e for s in sources for e in k.rows(s)]
    groups: dict[tuple, list[int]] = defaultdict(list)
    for e in entries:
        dims = {
            d["dimension"]["name"]: d["name"]
            for d in e.get("dimension-entries", {}).get("dimension-entries", [])
        }
        groups[
            (
                e.get("description", "").split("*")[0].split(",")[0].strip()[:22],
                e.get("expense-type", {}).get("name", "—"),
                dims.get("Tech & Dev-kategori", "— NONE —"),
                dims.get("Department", "— NONE —"),
                e.get("country-code", ""),
                e.get("digital"),
            )
        ].append(e["amount"])

    head = f"{'vendor':24}{'expense type':26}{'Tech & Dev':22}{'Dept':13}{'c':4}{'dig':5}{'n':>3}{'SEK':>12}"
    print(head)
    print("-" * len(head))
    for (vendor, tname, td, dept, ctry, dig), amts in sorted(groups.items()):
        print(
            f"{vendor:24}{tname[:24]:26}{td[:20]:22}{dept[:11]:13}{ctry:4}"
            f"{str(dig)[:4]:5}{len(amts):>3}{kr(sum(amts)):>12}"
        )
    print("-" * len(head))
    print(f"{'':94}{len(entries):>3}{kr(sum(e['amount'] for e in entries)):>12}")
    return 0


def cmd_match(k: Kleer, args) -> int:
    files = k.open_files()
    cards = k.open_cards()
    settled = [c for c in cards if not c.get("reservation")]
    held = [c for c in cards if c.get("reservation")]
    print(
        f"{len(files)} kvitton · {len(settled)} settled purchases "
        f"· {len(held)} reservations held back\n"
    )
    chosen, cand, leftover = assign(k, settled, files)
    type_dims = k.type_dims()
    for pin in args.pin or []:
        key, _, fid = pin.partition("=")
        chosen[key] = int(fid)

    planned = [(c, chosen[c["key"]]) for c in settled if c["key"] in chosen]
    ambiguous = [
        c for c in settled if c["key"] not in chosen and len(cand[c["key"]]) > 1
    ]
    unmatched = [
        c for c in settled if c["key"] not in chosen and len(cand[c["key"]]) <= 1
    ]

    print(
        f"=== {len(planned)} matched 1:1, {kr(sum(billing_of(c) for c, _ in planned))} SEK ==="
    )
    for c, fid in sorted(planned, key=lambda x: x[0]["date"]):
        print(
            f"  {c['date']}  {c.get('merchant', '')[:26]:28}"
            f"{kr(c.get('amount', 0)):>10} {c.get('currency-type', ''):4}"
            f" = {kr(billing_of(c)):>10} SEK  <- file {fid}"
        )
    if ambiguous:
        print(f"\n=== {len(ambiguous)} ambiguous — pin with --pin KEY=FILE_ID ===")
        for c in ambiguous:
            print(
                f"  {c['date']}  {c.get('merchant', '')[:26]:28}"
                f"{kr(c.get('amount', 0)):>10} {c.get('currency-type', '')}"
                f"  -> files {cand[c['key']]}   key {c['key']}"
            )
        print("  (amount alone cannot separate these — read the invoice numbers)")
    if unmatched:
        print(f"\n=== {len(unmatched)} with no receipt found ===")
        for c in sorted(unmatched, key=lambda x: x["date"]):
            print(
                f"  {c['date']}  {c.get('merchant', '')[:26]:28}"
                f"{kr(c.get('amount', 0)):>10} {c.get('currency-type', '')}"
            )
    if leftover:
        print(f"\n=== {len(leftover)} kvitton claimed by no purchase ===")
        for f in sorted(leftover, key=lambda x: x.get("registration-date", "")):
            print(
                f"  {f['id']}  {(f.get('registration-date') or '')[:10]}  "
                f"{f.get('filename', '')[:38]:40} {f.get('description', '')[:34]}"
            )

    if not args.apply:
        print("\n(report only — pass --apply to file them)")
        return 0

    created = 0
    for c, fid in planned:
        out = k.write("PUT", "expense/entry", entry_payload(c, fid, type_dims))
        created += "id" in out
    still = {c["key"] for c in k.open_cards()}
    left = [c["key"] for c, _ in planned if c["key"] in still]
    print(f"\ncreated {created}/{len(planned)} entries")
    print(f"purchases cleared : {len(planned) - len(left)}/{len(planned)}")
    return 0 if not left else 1


def cmd_file(k: Kleer, args) -> int:
    """Upload PDFs hunted down by hand and file each against its purchase."""
    cards = {c["key"]: c for c in k.open_cards()}
    type_dims = k.type_dims()
    jobs = []
    for pair in args.pairs:
        key, _, path = pair.partition("=")
        c = cards.get(key)
        if c is None:
            raise SystemExit(f"{key}: not an open card purchase")
        if c.get("reservation"):
            raise SystemExit(
                f"{key}: still a reservation — amount can move on settlement"
            )
        pdf = pathlib.Path(path)
        if not pdf.is_file():
            raise SystemExit(f"{pdf}: no such file")
        jobs.append((c, pdf))

    for c, pdf in jobs:
        print(
            f"  {c['date']}  {c.get('merchant', '')[:26]:28}"
            f"{kr(c.get('amount', 0)):>10} {c.get('currency-type', ''):4}"
            f" = {kr(billing_of(c)):>10} SEK  <- {pdf.name}"
        )
    if not args.apply:
        print("\n(report only — pass --apply to upload and file)")
        return 0

    for c, pdf in jobs:
        fid = k.put_file(pdf)
        out = k.write("PUT", "expense/entry", entry_payload(c, fid, type_dims))
        print(f"  entry {out['id']}  <- file {fid}  {c.get('merchant')}")
    still = {c["key"] for c in k.open_cards()}
    left = [c["key"] for c, _ in jobs if c["key"] in still]
    print(f"\npurchases cleared : {len(jobs) - len(left)}/{len(jobs)}")
    return 0 if not left else 1


def cmd_fix(k: Kleer, args) -> int:
    """Repair the fields the API gets wrong or silently drops."""
    sources = ["expense/entry/open"] + [
        f"expense/entry/expense/{n}" for n in args.expense_nr
    ]
    entries = [e for s in sources for e in k.rows(s)]
    todo = []
    for e in entries:
        vk = vendor_of(e.get("description", ""))
        have = e.get("dimension-entries", {}).get("dimension-entries", [])
        by_dim = {d.get("dimension", {}).get("id"): d["id"] for d in have}
        for d in e.get("expense-type", {}).get("dimensions", {}).get("dimensions", []):
            if d.get("entry"):
                by_dim.setdefault(d["id"], d["entry"]["id"])
        fixes = {}
        if vk and e.get("country-code") != COUNTRY[vk]:
            fixes["country-code"] = COUNTRY[vk]
        if not e.get("digital"):
            fixes["digital"] = True
        if len(by_dim) != len(have):
            fixes["dimension-entries"] = {
                "dimension-entries": [{"id": i} for i in by_dim.values()]
            }
        if fixes:
            todo.append((e, fixes))

    print(f"{len(entries)} entries examined, {len(todo)} need a correction\n")
    counts: dict[str, int] = defaultdict(int)
    for e, fixes in todo:
        for f in fixes:
            label = (
                f"country {e.get('country-code')} -> {fixes[f]}"
                if f == "country-code"
                else "digital -> true"
                if f == "digital"
                else "+ missing dimension"
            )
            counts[label] += 1
    for label, n in sorted(counts.items(), key=lambda x: -x[1]):
        print(f"  {n:>3} x  {label}")
    if not todo or not args.apply:
        if todo:
            print("\n(report only — pass --apply to correct them)")
        return 0

    for e, fixes in todo:
        k.write("POST", f"expense/entry/{e['id']}", rewrite_payload(e, **fixes))
    print(f"\ncorrected {len(todo)}")
    return 0


def cmd_drop(k: Kleer, args) -> int:
    """Delete receipt files, archiving the bytes first and refusing on any drift."""
    before = {f["id"]: f.get("filename", "") for f in k.open_files()}
    missing = [i for i in args.ids if i not in before]
    if missing:
        raise SystemExit(f"not in the kvitton queue: {missing}")
    print(f"{k.env}: {len(before)} kvitton\n\nwould DELETE:")
    for i in args.ids:
        print(f"  - {i}  {before[i]}")
    print(f"\nwould KEEP {len(before) - len(args.ids)}:")
    for i, n in sorted(before.items()):
        if i not in args.ids:
            print(f"    {i}  {n}")
    if not args.apply:
        print("\n(report only — pass --apply to delete)")
        return 0

    archive = STATE / "archive" / k.env
    archive.mkdir(parents=True, exist_ok=True)
    for i in args.ids:
        (archive / f"{i}_{before[i]}").write_bytes(k.blob(i))
    print(f"\narchived {len(args.ids)} file(s) to {archive}")
    for i in args.ids:
        k.client.delete(f"{k.base}/expense/file/{i}")
    after = {f["id"] for f in k.open_files()}
    removed = set(before) - after
    collateral = removed - set(args.ids)
    missed = set(args.ids) - removed
    print(f"  before {len(before)}  after {len(after)}  removed {len(removed)}")
    print(f"  collateral : {sorted(collateral) if collateral else 'none'}")
    print(f"  missed     : {sorted(missed) if missed else 'none'}")
    return 0 if not collateral and not missed else 1


def cmd_bundle(k: Kleer, args) -> int:
    """PUT expense IS the submission — there is no separate submit endpoint.

    Refuses unless the queue is exactly the ids given, so an entry that arrived
    since the report cannot be swept in unseen.
    """
    entries = k.open_entries()
    open_ids = {e["id"] for e in entries}
    approved = set(args.ids) if args.ids else open_ids
    if open_ids != approved:
        print("REFUSING — the queue does not match what was approved")
        print(f"  approved but gone : {sorted(approved - open_ids) or 'none'}")
        print(f"  appeared since    : {sorted(open_ids - approved) or 'none'}")
        return 1
    total = sum(e["amount"] for e in entries)
    print(f"{len(approved)} entries, {kr(total)} SEK")
    if not args.apply:
        print("\n(report only — pass --apply to submit for attest)")
        return 0
    payload = {
        "expense-entries": {"expense-entries": [{"id": i} for i in sorted(approved)]}
    }
    # the response carries the journal NR under the key "id" (nrs are 3 digits, ids 6)
    resp = k.write("PUT", "expense", payload)
    nr = resp.get("nr") or resp.get("id")
    held = k.rows(f"expense/entry/expense/{nr}")
    if {e["id"] for e in held} != approved:
        raise SystemExit(f"journal {nr} holds {sorted(e['id'] for e in held)}")
    print(f"submitted {len(held)} entries as journal nr {nr}, {kr(total)} SEK")
    print(
        "attest itself is the approver's action — you cannot certify your own journal"
    )
    return 0


def main() -> int:
    p = argparse.ArgumentParser(prog="kleer", description=__doc__)
    p.add_argument("--env", choices=["prod", "test"], default="prod")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status", help="queue overview").set_defaults(fn=cmd_status)

    a = sub.add_parser("audit", help="what is actually booked on each entry")
    a.add_argument("expense_nr", nargs="*", help="also include these journal nrs")
    a.set_defaults(fn=cmd_audit)

    m = sub.add_parser("match", help="match kvitton to kortköp and file them")
    m.add_argument("--apply", action="store_true")
    m.add_argument(
        "--pin",
        action="append",
        metavar="KEY=FILE_ID",
        help="resolve an ambiguous match by hand",
    )
    m.set_defaults(fn=cmd_match)

    f = sub.add_parser("file", help="upload hand-fetched PDFs and file them")
    f.add_argument("pairs", nargs="+", metavar="KEY=PATH.pdf")
    f.add_argument("--apply", action="store_true")
    f.set_defaults(fn=cmd_file)

    x = sub.add_parser("fix", help="repair country / digital / missing dimensions")
    x.add_argument("expense_nr", nargs="*", help="also include these journal nrs")
    x.add_argument("--apply", action="store_true")
    x.set_defaults(fn=cmd_fix)

    d = sub.add_parser("drop", help="delete kvitton, archiving them first")
    d.add_argument("ids", nargs="+", type=int)
    d.add_argument("--apply", action="store_true")
    d.set_defaults(fn=cmd_drop)

    b = sub.add_parser("bundle", help="submit the filed entries for attest")
    b.add_argument("ids", nargs="*", type=int, help="default: everything open")
    b.add_argument("--apply", action="store_true")
    b.set_defaults(fn=cmd_bundle)

    args = p.parse_args()
    return args.fn(Kleer(args.env), args)


if __name__ == "__main__":
    sys.exit(main())
