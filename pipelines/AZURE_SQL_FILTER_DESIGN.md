# AZURE_SQL — deployable filter set + path to target

> ## ✅ STATUS: R1–R3 + redaction processor DEPLOYED. R1-R3 VERIFIED. Redaction NOT YET VERIFIED.
> Live pipeline `9c7b26bd-11f3-432f-a7df-a30b56a8955f` now runs **4 processors**:
> R1/R2/R3 (exclude filters, confirmed byte-for-byte correct as of `updateTime = 2026-08-22T08:37:50`),
> plus a `redact_sensitive_data` processor added at `updateTime = 2026-08-22T09:00:02`
> containing all default preset rules (credit card, email, etc.) plus a custom rule
> targeting `"statement":"[^"]*"` to shrink the SQL text in each event.
>
> **The redaction processor's OUTPUT has NOT been checked against a live event —
> see "Redaction verification needed" below (tracked as BL-01 in FILTER_SCHEDULE.md).**
> R4 (logout/teardown, optional) has **not** been added.
> Baseline (original 2-rule state) preserved in [`azure_sql_filter.json`](./azure_sql_filter.json).
> Current full live state captured in [`azure_sql_filter_LIVE_20260822.json`](./azure_sql_filter_LIVE_20260822.json).

## Redaction verification needed (BL-01)

The custom rule `"statement":"[^"]*"` is designed to redact only the SQL text value inside
the `statement` field. Before trusting this in production, check ONE real AZURE_SQL log
entry and compare against these two possible outcomes:

- **✅ Intended:** `"statement":"***********************"` — only the text between the quotes
  is replaced with asterisks; the `"statement":` key label and surrounding JSON are untouched.
- **⚠️ Needs adjustment:** `*****************************` — the whole match, including the
  key label, is replaced. Not a security problem (nothing leaks either way), but may make the
  field harder for downstream parsing/readability. If this happens, narrow the rule to redact
  only the capture group value once BindPlane's exact replace-scope behaviour is confirmed.

How to check: find a recent AZURE_SQL entry in BindPlane's log preview (if available) or in
SecOps directly, and look at what the `statement` portion of the body now looks like.

**Governance basis:** Decision Paper *Filtering of AZURE_SQL*, 20/08/2026 (Johann de Winnaar). FILTER HEAVILY, P2, implementation point BindPlane. Target: retain ~20% of ≈34.526 GB/day.

---

## The position in one line

**Take the zero-evidentiary-cost reduction now; do not buy the remaining 80% by deleting exfiltration and insider-threat detection.**

## What this set does and does not do

| | |
|---|---|
| ✅ Reduces volume using only telemetry with **no security evidence** | |
| ✅ **Deployable without** resolving the Azure-retention question — nothing evidentiary is dropped | |
| ✅ Leaves exfiltration, insider-threat, authentication and permission-change detection **fully intact** | |
| ❌ **Will not reach 80%.** Making that claim would be dishonest | |

## Rules

| # | Drops | Cost | Basis |
|---|---|---|---|
| **R1** | 11 diagnostic/performance/health categories (extends live 6) | **Zero** | Grounded — `category` proven present |
| **R2** | `BATCH STARTED` markers | **Zero** | Grounded — already live |
| **R3** | Azure Monitor platform metrics records | **Zero** | Metrics-shape fingerprint; fails safe if absent. **DEPLOYED & VERIFIED** 2026-08-22T08:26:27 — byte-for-byte match confirmed via pipeline JSON export. |
| **R4** | *Optional* — session logout/teardown churn | Near-zero | Confirm `action_name` value first |

> **Deployment log:** R3 took three attempts to land correctly — two earlier saves silently no-op'd (a stray trailing newline, then a stray trailing escaped quote), both of which failed *safe* (dropped nothing) rather than unsafe. R1 (11-category superset, replacing the original 6-category processor) landed correctly on the first attempt. **Final state confirmed 2026-08-22T08:37:50** via pipeline JSON export: exactly 3 processors, all three regexes byte-for-byte matching spec, no extras, nothing missing. Lesson for future changes to this pipeline: after pasting a regex, click away or Tab rather than pressing Enter, and always verify via a pipeline JSON export rather than trusting `updateTime` alone — `updateTime` only proves *a* change landed, not that its content is correct.

**Deliberately excluded:** routine-DML drop (proposed D3) and successful-authentication drop (proposed D4). Rationale in *Security assessment* below.

### Safety properties
- `SQLSecurityAuditEvents` is **untouched** except paired-marker noise → no audit evidence lost
- **All FAILED events retained** — logins, authentications, statements
- **All successful logons retained** (R4 drops teardown only, never logon)
- Unknown/new category → **not** dropped (fails safe, costs reduction not visibility)
- `errorMode: IGNORE` → unparseable records survive
- `Errors` category deliberately **not** dropped pending decision

---

## Security assessment — why D3 and D4 are out

**D4 (drop successful logins): poor trade.** Auth events are small and rare, so savings are negligible — but successful authentication underpins brute-force-success detection (the failure→success transition), impossible travel, and compromise confirmation. Retaining failures while dropping successes leaves you the noise and removes the conclusion.

**D3 (drop routine successful DML): conflicts with the paper itself.** §4.1/§4.2 rate exfiltration and insider-threat detection **High**, and §7.4 mandates retaining export/bulk-extraction/large-query activity. But database exfiltration and insider abuse consist almost entirely of *successful* SELECTs by *legitimately authenticated* accounts. With **no volumetric field** in this feed (no rows-returned/bytes/duration), a 10-row app query and a mass extraction are indistinguishable — both would be dropped.

D3 also has engineering defects: it anchors on the statement *starting* with a DML keyword, so it misses `/* hint */ SELECT`, `SET NOCOUNT ON; SELECT`, `WITH cte AS (…) SELECT`, and `EXEC sp_executesql`. In a stored-procedure-heavy estate it may reduce almost nothing — under-delivering while still carrying full detection risk.

**Escalate, don't engineer around:** if the security criteria in §7.4 and the 80% figure cannot coexist, the security criteria should win and the number should be revised. A percentage reverse-engineered from cost is not a security requirement.

---

## Step 2 — measure, then decide (the actual unlock)

The 80% argument is currently opinion on both sides. **Measure the byte distribution and it becomes arithmetic.**

1. Baseline AZURE_SQL daily volume (paper says 34.526 GB/day — re-confirm).
2. Break volume down **by `category`** — this tells you what R1/R3 actually recover.
3. Within `SQLSecurityAuditEvents`, break down **by `action_name`**, and estimate **average event size**.

Use the SecOps ingestion metrics/dashboards plus a statistics-style search grouped by category (confirm exact syntax in your tenant).

**What the numbers will tell you:**
- If diagnostics/metrics are a large share → R1+R3 may get you most of the way with **zero** detection cost.
- If `SQLSecurityAuditEvents` dominates **by event count** → look at dedup (repetitive ORM/app query shapes).
- If it dominates **by event size** → the bytes are in the `statement` / `additional_information` text, and **field pruning is the answer, not event dropping.**

## Step 3 — close the gap without losing detection

Preferred order once measured:

1. **Prune fields, don't drop events.** Truncate/strip `statement` and `additional_information`, keep the skeleton (principal, client IP, database, object, action, outcome, timestamp). Kills most bytes, retains who-touched-what-from-where. Google documents these pipelines as able to [filter events, transform fields, or redact values before ingestion](https://docs.cloud.google.com/chronicle/docs/ingestion/data-processing-pipeline) — confirm the transform/redact processor is exposed in your UI. *(Rephrased for licensing compliance.)*
2. **Dedup repetitive application traffic** — collapse identical query shapes per principal/object over a window, retain counts.
3. **Scope by asset sensitivity** — filter routine DML only for low-sensitivity application databases; retain in full for databases holding patient/sensitive data. Most defensible under audit. Needs a data-classification input.
4. **Sampling** (1-in-N) only if 1–3 fall short.

---

## Open decisions

| # | Decision | Owner |
|---|---|---|
| 1 | `Errors` category — drop as noise, or retain for investigation value? | Cyber Defence |
| 2 | `Blocks`/`Deadlocks` (in R1) — confirm no approved detection depends on them | Cyber Defence |
| 3 | Backup contradiction — §7.5 filters backups, but **restore** is a tamper/exfil vector. Filter backups only, or both? | Cyber Defence |
| 4 | R4 `action_name` value — confirm before enabling | Analyst |
| 5 | **Is full Azure-side audit retention real, complete, and retrievable in incident timeframes?** Gates any future evidentiary filtering | Cloud/Azure Eng |
| 6 | Do any of these databases hold patient/sensitive data? Gates option 3 above | IG / DPO |

## Silent-failure controls (§7.6)

SecOps rules **do not error when their source data disappears — they just stop firing.** Zero alerts looks identical to zero threats. Therefore:
- Capture a **rule-firing baseline** before/after
- Deploy **canary events** per retained category and confirm arrival
- Alert on a **volume floor** per log type (if AZURE_SQL approaches zero, something over-filtered)
- Note: **dropped data cannot be retro-hunted.** An IOC arriving in three months has nothing to hunt against

## Deployment note

These are **Google SecOps `logProcessingPipelines`** (Chronicle API) authored via BindPlane's SecOps Pipelines UI — not BindPlane processor resources. Update pipeline `9c7b26bd-…` in place so history/metadata is preserved. `scripts/apply.sh` (BindPlane CLI) does **not** apply these.
