# Google SecOps — Filter Schedule

The **single register** of every filter/pipeline in scope for Google SecOps ingestion.

- **SecOps Pipelines** (the `/secops-pipelines` view) are the named volume-reduction filters — this is the primary list you asked for.
- Reconciled from the live instance via `export-filters.sh` (REST for processors/configs + GraphQL `secOpsPipelineSummaries` for the SecOps Pipelines).

> Source of truth for **review** = this file. Source of truth for **runtime** = the live instance. Reconcile after every change.

**Last reconciled:** 2026-08-22 (snapshot `20260822T072129Z`)
**Instance:** `https://app.bindplane.com`
**Project:** Google SecOps UK (`01KC4W80ECMCJ8QJ9AG85S9S5J`)

---

## 1. SecOps Pipelines — named volume-reduction filters

> Source: GraphQL `secOpsPipelineSummaries` (the `/secops-pipelines` UI page). Times are UTC.

| Filter | Purpose | Log type(s) | Created | Last modified |
|--------|---------|-------------|---------|---------------|
| **AWS_Filter** | CloudTrail log volume reduction | _(none set)_ | 2026-08-14 | 2026-08-19 |
| **AWS_Filter2** | AWS WAF log volume reduction | _(none set)_ | 2026-08-17 | 2026-08-20 |
| **Azure_SQL_Filter** | Azure SQL log — **heavily filtered per governance decision 20/08/2026** | `AZURE_SQL` | 2026-08-18 | **2026-08-22** (3 processors, up from 2) |
| **Microsoft_Insights_Components** | _(no description)_ | `MICROSOFT_INSIGHTS_COMPONENTS` | 2026-08-20 | 2026-08-20 |
| **ZSCALER_Filter** | Zscaler Webproxy filter | _(none set)_ | 2026-08-21 | 2026-08-21 |

**Pipeline IDs (for API/automation):**

| Filter | ID |
|--------|-----|
| AWS_Filter | `c072e6b7-0690-419c-82ca-901b7ab2bc3f` |
| AWS_Filter2 | `6f17d9b9-8874-4c5b-9a54-eca796841abc` |
| Azure_SQL_Filter | `9c7b26bd-11f3-432f-a7df-a30b56a8955f` |
| Microsoft_Insights_Components | `54d1435e-1c44-44f3-a581-ee7ff2a83448` |
| ZSCALER_Filter | `7d023b21-3b13-4580-9174-a86b14dace06` |

### Detailed rules

| Filter | Detailed rules doc |
|--------|--------------------|
| Azure_SQL_Filter | [`../pipelines/AZURE_SQL_FILTER_DESIGN.md`](../pipelines/AZURE_SQL_FILTER_DESIGN.md) — **LIVE as of 2026-08-22**, verified state: [`azure_sql_filter_LIVE_20260822.json`](../pipelines/azure_sql_filter_LIVE_20260822.json). Original 2-rule baseline: [`azure_sql_filter.json`](../pipelines/azure_sql_filter.json) |
| AWS_Filter | Live: 3 enumerated eventName drop rules (read-only Describe/Get/List; rule 2 ~97% redundant with rule 1). Proposed 2 new rules + rationale in [`../pipelines/aws_cloudtrail_filter.json`](../pipelines/aws_cloudtrail_filter.json); deploy guide [`../pipelines/DEPLOY_AWS_CLOUDTRAIL.md`](../pipelines/DEPLOY_AWS_CLOUDTRAIL.md). Feed `2ff7b983-...`. KMS Encrypt/GenerateDataKey drop = prior decision, left as-is. |
| AWS_Filter2 | _(not yet captured)_ |
| Microsoft_Insights_Components | _(not yet captured)_ |
| ZSCALER_Filter | Live: 1 rule (drop Darktrace sensor phone-home). Captured + proposed extension in [`../pipelines/zscaler_filter.json`](../pipelines/zscaler_filter.json); deploy guide [`../pipelines/DEPLOY_ZSCALER.md`](../pipelines/DEPLOY_ZSCALER.md). Note: filter is scoped to ONE feed (`02d280ff-...`). |

> **Important — where the rules live:** these SecOps Pipelines are **Google SecOps `logProcessingPipelines`** (Chronicle API resources) authored via BindPlane's SecOps UI. They are NOT BindPlane configuration/processor resources, so BindPlane's REST/GraphQL read APIs do **not** return the rule bodies (only the summary list). To capture a pipeline's detailed rules, export its definition from the SecOps side (the `logProcessingPipelines` API / UI export) — that JSON is the authoritative source.

---

## Volume baseline (BL-02 measurement anchor)

Captured from the SecOps "Log Volume (GB) by Log Type — Last 30 Days" report,
window **24 Jul → 22 Aug 2026 09:42**. This is the **BEFORE** baseline: today's filters
(CloudTrail A+B, Azure SQL exclude+redact, Zscaler Z1) went live only in the final ~1–2h
of this window, so their impact is NOT reflected here yet. Re-measure the daily figure in
24–48h and compare against the daily-average column below.

| Log type | 30-day total GB | Daily avg GB | Events (30d) | Touched today? |
|----------|----------------:|-------------:|-------------:|----------------|
| AWS_CLOUDTRAIL | 6400.25 | **213.34** | 3,516,895,644 | ✅ Rules A+B |
| AZURE_SQL | 6150.23 | **205.01** | 2,096,953,617 | ✅ exclude R1/R3 + redaction |
| ZSCALER_WEBPROXY | 2840.63 | **94.69** | 2,204,620,828 | ✅ Rule Z1 (Microsoft only so far) |
| AWS_WAF | 1953.45 | 65.12 | 854,900,072 | — (AWS_Filter2, not yet reviewed) |
| AZURE_ACTIVITY | 842.41 | 28.08 | 410,974,487 | — |
| MICROSOFT_INSIGHTS_COMPONENTS | 816.13 | 27.20 | 196,123,987 | ✅ **removed 21 Aug** — now 0 GB/day |
| AZURE_GATEWAY | 814.02 | 27.13 | 404,780,203 | — |

> Notes:
> - **MICROSOFT_INSIGHTS_COMPONENTS is already at 0 GB / 0 events today** — confirmed as a
>   deliberate removal on 2026-08-21 (not a broken feed). ~27 GB/day already banked.
> - The three filters deployed today target the **top 3 log types by volume** — the changes
>   were made exactly where the volume is.
> - Column values are: 30-day total / daily average / event count, as read from the report.

## Backlog / follow-up checks

| ID | Item | Why it matters | Status |
|----|------|-----------------|--------|
| BL-01 | **Verify `redact_sensitive_data` output on Azure_SQL_Filter.** Confirm the custom rule `"statement":"[^"]*"` redacts only the SQL text value, not the surrounding `"statement":` key label too. Check a live/recent AZURE_SQL log entry in BindPlane/SecOps. Either outcome is safe (no data leak either way) — but if the key label is also redacted, downstream parsing/readability could be affected. See `../pipelines/AZURE_SQL_FILTER_DESIGN.md` for the two possible outcomes to look for. | Deployed 2026-08-22T09:00:02 without this check due to time constraints. | ⏳ Open |
| BL-02 | **Measure actual AZURE_SQL volume reduction** from the R1+R3 exclude filters and the redact processor. Break down by `category`, and within `SQLSecurityAuditEvents` by `action_name` + average event size, to size the real saving and decide if further work (R4, dedup, asset-scoped filtering) is worth pursuing. | Nothing has been measured yet — all reduction estimates so far are structural, not observed. | ⏳ Open |
| BL-03 | **Confirm no live SecOps detection depends on `Blocks` or `Deadlocks`** (Azure SQL categories added in R1). One-line confirmation needed from Cyber Defence. | Gate on R1 that was never formally closed before deploying. | ⏳ Open |
| BL-04 | **Decide on `Errors` category** — drop as operational noise, or retain for investigation value (failed statements, injection attempts)? Currently retained (not dropped) by default. | Open decision from the governance decision paper, not yet actioned. | ⏳ Open |
| BL-05 | **Apply the same zero-evidentiary-cost review to remaining filters.** Done: AWS_Filter (CloudTrail), ZSCALER_Filter (Microsoft rule only). Remaining: **AWS_Filter2 (AWS_WAF, ~65 GB/day — next biggest untouched)**, Microsoft_Insights_Components (already removed 21 Aug). Zscaler Z2–Z4 (Google/Apple/CDN) still parked. | Partially done. AWS_WAF is the largest remaining untouched source. | ⏳ In progress |
| BL-07 | **Zscaler: add a "drop all blocked" rule.** Owner confirmed blocked traffic is reviewed in the Zscaler console and needn't be in SecOps. Needs one real Zscaler event to confirm the exact `action` value for blocked (`Blocked`/`Denied`/etc.) before building. | Biggest remaining Zscaler saving after the trusted-domain drops; safe once the value is confirmed. | ⏳ Open |
| BL-08 | **Zscaler: confirm whether more than one Zscaler feed** flows into SecOps. The current filter is scoped to a single feed (`02d280ff-...`); other feeds would need the same rules. | Filters scoped per-feed; other feeds get no reduction until covered. | ⏳ Open |
| BL-06 | **Rotate the BindPlane API keys** used during this session (both the original `bp_...` key and the `bps_...` Google SecOps UK key) — they were shared in chat and should be treated as exposed. | Basic credential hygiene. | ⏳ Open |

## 2. Other SecOps processing on the instance (context)

### Reusable Blueprint bundles (library)

| Bundle | Purpose | Key steps |
|--------|---------|-----------|
| `crowdstrike-falcon-google-secops-volume-reduction` | Cut CrowdStrike Falcon FDR volume | parse_json → drop low-signal / benign DNS / RFC1918 → prune → dedup → SecOps standardization |
| `reduce-cloudtrail-logs` | Drop read-only AWS CloudTrail | parse_json → filter read-only → delete empty |

### Inline processors on live config

| Config → destination | Processors |
|----------------------|-----------|
| `OptumUKWinEvtLog` → `ptmkc` (Chronicle) | `copy_field` (host.name → ingestion_source label), `batch` (1024/2048/10s) |

---

## How to refresh this schedule

```bash
cd inventory
cp .env.example .env      # set BINDPLANE_URL, BINDPLANE_API_KEY, BINDPLANE_ACCOUNT_ID
./export-filters.sh       # writes a timestamped snapshot + prints the SecOps Pipelines
```

---

## Change log

| Date | Change | By |
|------|--------|-----|
| 2026-08-22 | Located the 5 SecOps Pipeline filters via GraphQL `secOpsPipelineSummaries` and recorded them (AWS_Filter, AWS_Filter2, Azure_SQL_Filter, Microsoft_Insights_Components, ZSCALER_Filter). Added GraphQL + account-header support to export-filters.sh. | export-filters.sh |
| 2026-08-22 | Deployed & verified R1 (11-category exclude, superset of original 6) + R3 (Azure Monitor metrics exclude) on Azure_SQL_Filter. Now 3 processors, zero-evidentiary-cost. Reduction not yet measured. | manual UI deploy, verified via JSON export |
| 2026-08-22 | Deployed & verified ZSCALER_Filter Rule Z1 (drop allowed + no-threat browsing to Microsoft/Office/Windows/Azure). Now 2 processors (Darktrace + Microsoft). Z2/Z3/Z4 (Google/Apple/CDN) still pending manual add. Reduction not yet measured — watch dashboard. | manual UI deploy, verified via JSON export |
| 2026-08-22 | Deployed & verified AWS_Filter (CloudTrail) Rule A (drop readOnly:true — AWS's own read-only classification) + Rule B (drop invokedBy AWS-service automation). Now 5 processors. Recon-detection use-case covered by existing GuardDuty feed. Reduction not yet measured — watch dashboard; Rule A likely makes the 3 enumerated rules largely redundant. | manual UI deploy, verified via JSON export |
