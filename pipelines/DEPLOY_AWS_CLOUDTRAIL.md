# Deploying the AWS CloudTrail (AWS_Filter) additions

Two new "Filter by Regex" processors that drop read/automation noise the existing
enumerated-name rules miss — using CloudTrail's own fields instead of a hand-maintained
list of 800+ event names.

**Pipeline:** `AWS_Filter`
**Edit here:** https://app.bindplane.com/p/01KC4W80ECMCJ8QJ9AG85S9S5J/secops-pipelines/c072e6b7-0690-419c-82ca-901b7ab2bc3f
**Rollback:** current 3-rule state preserved in `aws_cloudtrail_filter.json` context. Screenshot/export before editing.

## Security rationale (why this is safe)

- CloudTrail = "who looked" (read) vs "who changed something" (write). Attacks are almost
  always **writes**. All writes are kept.
- **Rule A drops what AWS itself flags `readOnly:true`** — AWS's own authoritative classification,
  not our guess. Catches all read noise incl. names the existing lists miss.
- KMS `Encrypt`/`GenerateDataKey` are `readOnly:false` → **kept** (consistent with the prior KMS decision).
- The one capability read-only logs support — **recon/enumeration detection** — is already
  delivered, better, by **GuardDuty**, which is already ingested. So no detection capability is lost.
- **Rule B** drops "AWS talking to itself" (service automation) — machines, not people/attackers.

## Form settings — same for both rules

| Field | Value |
|---|---|
| **Action** | `Exclude` |
| **Match** | `Body` |
| **Field** | *(leave empty)* |

## Rule A — drop AWS-classified read-only events (the big win)
Short Description: `Drop CloudTrail readOnly:true events (recon covered by GuardDuty)`
```
"readOnly"\s*:\s*true
```

## Rule B — drop AWS service-internal automation
Short Description: `Drop CloudTrail events invoked by AWS services (automation noise)`
```
"invokedBy"\s*:\s*"[a-z0-9.\-]+\.amazonaws\.com"
```

## Steps

1. Open the pipeline URL, export/screenshot current state (rollback).
2. Leave the 3 existing rules alone.
3. Add Rule A as a new "Filter by Regex" processor (Action=Exclude, Match=Body, Field empty).
   - After pasting the regex, click away / Tab — do NOT press Enter.
4. Save → **Rollout**. Paste the pipeline JSON back so it can be verified.
5. Watch the CloudTrail ingestion volume — Rule A alone likely makes the 3 enumerated
   rules mostly redundant.
6. Once A is confirmed working, repeat for Rule B.

## Notes / caveats

- Built against the **documented, stable CloudTrail record schema** (no live sample was
  available). `readOnly` is a JSON boolean; `invokedBy` is the AWS-service caller string.
- **Fails safe:** if the real format differs, the rule matches nothing and drops nothing —
  verify via the volume dashboard after deploy, and ideally eyeball one CloudTrail event in
  SecOps once you have access, to confirm Rule A is actually firing.
- Both rules match a single field anywhere in the body, so they are **not** sensitive to field order.
- Safety-tested (10 cases) before proposal: writes, KMS Encrypt, DeleteTrail, real-user calls,
  and a decoy body containing the word "true" elsewhere are all correctly KEPT.

## Optional cleanup (later, not now)

Once Rule A is confirmed effective, the 3 existing enumerated-name rules are largely
redundant (Rule A supersedes them, and existing Rule 2 was already ~97% redundant with
Rule 1). They can be simplified, but leave working rules in place until Rule A is proven.
