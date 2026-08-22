# Deploying the AZURE_SQL filter changes

> Paste-ready values generated directly from `azure_sql_filter_v2.json` — do **not** retype these.
> The JSON file is a **spec/record**, not an uploadable artefact. You configure processors in the UI.

**Pipeline:** `Azure_SQL_Filter`
**Edit here:** https://app.bindplane.com/p/01KC4W80ECMCJ8QJ9AG85S9S5J/secops-pipelines/9c7b26bd-11f3-432f-a7df-a30b56a8955f

**Rollback:** the current 2-rule definition is preserved in `azure_sql_filter.json`. Screenshot/export before editing.

---

## The change is smaller than it looks

The live pipeline already has 2 processors. You are making **one edit and one addition**:

| Live processor | Action |
|---|---|
| 1 — category filter (6 categories) | **REPLACE** its condition with R1 below (6 → 11 categories) |
| 2 — `BATCH STARTED` | **LEAVE UNCHANGED** — already correct |
| *(new)* 3 | **ADD** R3 below (Azure Monitor metrics) |
| *(new)* 4 | **DO NOT ADD YET** — R4 needs a field value confirmed first |

---

## R1 — replace processor 1's condition

Extends the dropped categories from 6 to 11. `errorMode: IGNORE`.

```
body != nil and IsString(body) and IsMatch(body, "\"category\":\\s*\"(DatabaseWaitStatistics|QueryStoreWaitStatistics|QueryStoreRuntimeStatistics|ResourceUsageStats|Timeouts|AutomaticTuning|WorkflowRuntime|Blocks|Deadlocks|SQLInsights|DatabaseInstances)\"")
```

## R3 — add as a new processor

Drops Azure Monitor platform metrics records. `errorMode: IGNORE`.
Fails safe: if no metrics reach this log type, it simply never fires.

```
body != nil and IsString(body) and IsMatch(body, "\"metricName\":") and IsMatch(body, "\"timeGrain\":\\s*\"PT")
```

## R4 — do NOT add yet (reference only)

Confirm the real `action_name` for logout in a live event first, then add if wanted.

```
body != nil and IsString(body) and IsMatch(body, "\"action_name\":\\s*\"(LOGOUT|DATABASE AUTHENTICATION LOGOUT|CONNECTION CLOSED)\"")
```

---

## Steps

1. Open the pipeline URL above.
2. **Export/screenshot the current definition** (your rollback).
3. Edit processor 1 → replace its condition with **R1**. Keep `errorMode = IGNORE`.
4. Add a new filter processor → paste **R3**. Set `errorMode = IGNORE`.
5. Leave processor 2 alone. Do not add R4.
6. Save, then **sync / rollout** the pipeline.
7. Confirm `updateTime` changes (see verification below).

## Pre-flight gates

- [ ] Confirm no live SecOps rule depends on `Blocks` or `Deadlocks` (new in R1) — §7.6
- [ ] Confirm you accept `Errors` being retained (deliberately not dropped)
- [ ] Change record raised / Johann's sign-off if required under the decision paper

## Verification after deploy

Baseline before: `updateTime = 2026-08-20T10:35:01.605343Z`, 2 processors.

Expect after: `updateTime` moves to your deploy time, 3 processors.

Then measure: break AZURE_SQL volume down by `category`, and within
`SQLSecurityAuditEvents` by `action_name` + average event size. That tells you the
real size of the dent and which lever to pull next.

## If you prefer the API instead of the UI

These are Chronicle-side resources, so the write path is the Google SecOps
`logProcessingPipelines` API — **not** BindPlane's API and not `scripts/apply.sh`.
It needs SecOps-side credentials (service account / gcloud OAuth) with pipeline
admin rights, which are separate from the BindPlane API key.

Resource name:
```
projects/721279881207/locations/europe-west2/instances/c98f7d82-a2a4-45a1-a96a-a4dee6cf39fd/logProcessingPipelines/9c7b26bd-11f3-432f-a7df-a30b56a8955f
```

A PATCH with an update mask covering `processors` is the shape, but confirm the
exact endpoint, version and mask semantics against Google's documentation before
using it: https://docs.cloud.google.com/chronicle/docs/ingestion/data-processing-pipeline

**Recommendation: use the UI.** It is the validated path, it keeps the audit trail
in BindPlane, and it avoids a malformed PATCH against a live security control.
