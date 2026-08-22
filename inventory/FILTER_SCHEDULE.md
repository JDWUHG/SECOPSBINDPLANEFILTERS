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
| **Azure_SQL_Filter** | Azure SQL log | `AZURE_SQL` | 2026-08-18 | 2026-08-20 |
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

> Notes:
> - `AWS_Filter`, `AWS_Filter2`, `ZSCALER_Filter` have **no `logTypes` set** on the pipeline summary — worth confirming the target log type is applied inside the pipeline, otherwise routing/parsing may fall back.
> - `Microsoft_Insights_Components` has **no description** — candidate for a one-line description for consistency.
> - The detailed drop/keep rule logic for each pipeline is not exposed on the summary object; retrieving it needs the per-pipeline configuration (next step — see below).

---

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
