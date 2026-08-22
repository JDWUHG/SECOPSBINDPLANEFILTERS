# Azure_SQL_Filter — detailed rules

Detailed rule breakdown for the **Azure_SQL_Filter** SecOps Pipeline. Raw definition: [`azure_sql_filter.json`](./azure_sql_filter.json).

> **Where this lives:** This is a **Google SecOps `logProcessingPipeline`** (Chronicle API resource), surfaced/authored through BindPlane's SecOps Pipelines UI. It is *not* a BindPlane configuration/processor resource — which is why it isn't returned by the BindPlane REST/GraphQL read APIs. The authoritative source is the SecOps API definition above.

## Identity

| Field | Value |
|---|---|
| Display name | `Azure_SQL_Filter` |
| Description | Azure SQL Log |
| Pipeline ID | `9c7b26bd-11f3-432f-a7df-a30b56a8955f` |
| SecOps resource | `projects/721279881207/locations/europe-west2/instances/c98f7d82-…/logProcessingPipelines/9c7b26bd-…` |
| GCP project | `721279881207` |
| Region | `europe-west2` |
| SecOps customer ID | `c98f7d82-a2a4-45a1-a96a-a4dee6cf39fd` |
| **Stream / log type** | `AZURE_SQL` |
| Ingestion method | All Ingestion Methods |
| Created / Modified | 2026-08-18 / 2026-08-20 |

## How to read these rules

- Each entry is a **`filterProcessor`** with one or more `logConditions` (OTTL boolean expressions).
- **A record that MATCHES a `logCondition` is DROPPED** (filtered out before ingest into SecOps). Everything else passes through.
- `errorMode: IGNORE` — if a record can't be evaluated (e.g. malformed body), the error is ignored and the record is **not** dropped by that rule; the pipeline keeps running.
- Processors run in order; a record dropped by rule 1 never reaches rule 2.

## Rule 1 — Drop high-volume Azure SQL diagnostic categories

**OTTL condition:**
```
body != nil and IsString(body) and IsMatch(body,
  "\"category\":\s*\"(DatabaseWaitStatistics|QueryStoreWaitStatistics|ResourceUsageStats|Timeouts|AutomaticTuning|WorkflowRuntime)\"")
```

**Meaning:** drops any log whose JSON body has a `category` field equal to one of these six Azure SQL diagnostic categories:

| Dropped `category` | What it is |
|---|---|
| `DatabaseWaitStatistics` | DB wait-stat telemetry (high volume, low security value) |
| `QueryStoreWaitStatistics` | Query Store wait stats |
| `ResourceUsageStats` | Resource usage metrics |
| `Timeouts` | Query/command timeout events |
| `AutomaticTuning` | Automatic tuning recommendations/actions |
| `WorkflowRuntime` | Workflow runtime telemetry |

**Guards:** `body != nil and IsString(body)` — only evaluates when the body exists and is a string (JSON string body), avoiding errors on non-string payloads.

## Rule 2 — Drop SQL audit "BATCH STARTED" noise

**OTTL condition:**
```
body != nil and IsString(body) and IsMatch(body, "\"action_name\":\s*\"BATCH STARTED\"")
```

**Meaning:** drops any log whose JSON body has `action_name` = `BATCH STARTED`. These are SQL audit batch-start markers — very high volume, minimal detection value (the corresponding statement/completion events carry the signal).

**Guards:** same `body != nil and IsString(body)` guard as rule 1.

## Net effect

`AZURE_SQL_Filter` reduces `AZURE_SQL` ingest volume by dropping:
1. Six categories of Azure SQL diagnostic/performance telemetry, and
2. SQL audit `BATCH STARTED` records.

Security-relevant audit events (logins, permission changes, completed statements, etc.) are **not** matched by either condition and continue to flow into SecOps.

## Notes / observations

- Both rules match on the **raw JSON string body** via regex (`IsMatch`), not parsed attributes — robust to unparsed logs, but sensitive to exact JSON formatting/spacing (the `\s*` after the colon allows for the usual `": "` spacing).
- No `keep`-style condition is present; this is purely subtractive (drop-only).
- Consider whether `WorkflowRuntime`/`AutomaticTuning` are ever needed for change-tracking; if so they could be narrowed. (Observation only — no change made.)
