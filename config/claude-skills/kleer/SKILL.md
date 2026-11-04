---
name: kleer
description: Handle receipts and utlägg in Kleer (PE Accounting) for Arthro Therapeutics AB. Use when the user mentions Kleer, kvitton, kortköp, utlägg, expense receipts, month-end expense reporting, matching receipts to card purchases, or submitting expenses for attest.
allowed-tools: Bash(kleer *)
---

# Kleer expenses

Use the `kleer` CLI. Every mutating subcommand reports first and only acts with `--apply`.

Token: `KLEER_PERSONAL_ACCESS_TOKEN` in `~/work/.env`, read inline — **never read that file**.
Company 4483 (Arthro Therapeutics AB). Default env is prod; `--env test` exists but see below.

## Month-end flow

```bash
kleer status                  # what is in each queue
kleer match                   # match kvitton to kortköp, 1:1, report only
kleer match --apply           # file them all (this is the "spara" click, batched)
kleer fix                     # check country / digital / dimensions
kleer fix --apply             # repair them
kleer audit                   # what is ACTUALLY booked, grouped by vendor
kleer bundle --apply          # submit everything for attest
```

Then clean up what is left:

```bash
kleer drop 4435870 4501605            # dry run: shows delete list AND keep list
kleer drop 4435870 4501605 --apply    # archives bytes, deletes, diffs the queue
```

## Receipts that must be fetched by hand

OpenAI and Twilio recharges are portal-only — no receipt is ever emailed. Download them,
then file each against its purchase key (get keys from `kleer match`):

```bash
kleer file 01a11a58-...=~/Downloads/Receipt-2829-9829-6438.pdf --apply
```

## Ambiguity

`kleer match` matches on the purchase's **original** printed amount, not billing SEK —
billing moves with FX between authorisation and settlement. When one vendor charges the
same amount twice, or a statement restates several charges, several files fit. Read the
**invoice numbers** out of the PDFs and pin by hand:

```bash
kleer match --pin 01a18a1d-...=4501607 --pin 01a177f4-...=4493446 --apply
```

## Rules that the API does not enforce

- **A card-linked entry books in SEK at the billing amount**, `currency-rate: 1.0`.
  Sending the purchase's own USD/EUR figure is refused with
  `CardTransactionAmountMismatchWithCompanyCardExpenseEntryException`; omitting the amount
  gives a bare `Tekniskt fel`.
- **Tech & Dev-kategori is not automatic.** Kleer hangs a default dimension entry off the
  expense *type*; the web UI copies it onto the entry, the API does **not**. `kleer fix`
  repairs this. When auditing, read the entry's own `dimension-entries` — a listing that
  shows the type's template will look fine when the entry is actually missing it.
- **Country is the supplier's domicile on the letterhead**, not where its EU VAT
  registration sits. Anthropic shows `EU VAT: IE…` but is a San Francisco company, so US.
  Atlassian (Sydney) and DocEvent (NSW) are AU. Google Cloud EMEA (Dublin) is IE.
- **Never file against a `reservation: true` purchase** — the amount still moves on
  settlement. `kleer match` holds them back automatically.
- Foreign SaaS is reverse charge: `vat: 0`.

## Submitting

`PUT expense` **is** the submission; there is no separate submit endpoint. `kleer bundle`
does it and refuses unless the open queue is exactly what was approved.

`POST expense/:nr/certify` is the **approver's** action. Axel cannot attest his own journal
(`ExpenseCertifyAccessDenied`), so the CLI deliberately does not expose it.

## Things that are not expenses

Supplier invoices paid by **bank transfer** (Aikido) are not card expenses and never match
a kortköp. They belong in the leverantörsfaktura flow via
`arthrotherapeuticsab@invoice.kleer.se`. They reach the kvitton queue only because a Gmail
rule forwards them to `kvitton@expense.kleer.se`. Drop them from the queue; fix the rule.

## Gotchas

- **Test env is useless here**: `expense/card-transaction/open` returns 0 rows in test even
  though prod has dozens — the nightly mirror does not carry the kortköp queue. Rehearse by
  running without `--apply`, not by switching env.
- Kleer picks the **response** format from the **request** `Content-Type`, not `Accept`.
  The file upload must send `application/pdf`, so that one call answers in XML.
- An API-uploaded PDF gets a UUID filename. Only email-ingested files keep their name.
- `expense?filter=all` lists **reimbursable** expenses only — a journal of company-card
  entries never appears there. Use `expense/entry/expense/:nr`.
- Receipt PDFs are cached under `~/.cache/kleer/receipts/<env>/`; deleted files are
  archived to `~/.cache/kleer/archive/<env>/` before deletion.
