# Deploying the AZURE_SQL filter changes

Each rule below is one **"Filter by Regex"** processor. Fill the form exactly as shown.
The UI generates the OTTL wrapper and escaping itself, so paste **only the regex**.

**Pipeline:** `Azure_SQL_Filter`
**Edit here:** https://app.bindplane.com/p/01KC4W80ECMCJ8QJ9AG85S9S5J/secops-pipelines/9c7b26bd-11f3-432f-a7df-a30b56a8955f
**Rollback:** current 2-processor definition preserved in `azure_sql_filter.json` — screenshot/export first.

## Form settings that apply to every rule

| Field | Value | Why |
|---|---|---|
| **Action** | `Exclude` | Removes matching logs |
| **Match** | `Body` | The regex is evaluated against the log body |
| **Field** | *(leave empty)* | Evaluates the entire body — see note below |

> **Why `Field` is left empty:** the live working rule guards with `IsString(body)` and regexes the raw
> body text, which means the body arrives as an **unparsed JSON string**, not a structured map
> (consistent with SecOps guidance to send logs raw). A string body has no addressable sub-fields, so
> `Field` must stay empty.
>
> Setting `Field` to e.g. `category` would be *more precise* and would remove the small risk of a
> whole-body match hitting the same text inside a SQL statement. Worth testing — but **separately**,
> not bundled into this change.

## Two rules of this processor model

1. **One regex per processor** — you cannot AND two conditions in a single processor.
2. **Multiple processors = OR** — each drops independently.

(`Action: Include` also exists — it retains only matching logs. Not used here.)

---

## The change: one edit, one addition

| Processor | Action |
|---|---|
| 1 — category exclude | **REPLACE** the regex with R1 (6 → 11 categories) |
| 2 — `BATCH STARTED` | **LEAVE ALONE** — already correct |
| *new* 3 | **ADD** R3 |
| *new* 4 | **DO NOT ADD YET** (R4) |


---

## R1 — non-security diagnostic / performance / health categories

**REPLACE the existing processor 1 regex. Strict superset of the live 6 categories: 5 added, 0 removed.**

| Form field | Value |
|---|---|
| Short Description | Exclude non-security Azure SQL diagnostic and performance categories (gov 20/08/2026) |
| Action | Exclude |
| Match | Body |
| Field | *(leave empty)* |

**Regex:**

```
"category":\s*"(DatabaseWaitStatistics|QueryStoreWaitStatistics|QueryStoreRuntimeStatistics|ResourceUsageStats|Timeouts|AutomaticTuning|WorkflowRuntime|Blocks|Deadlocks|SQLInsights|DatabaseInstances)"
```

Cost: Zero. None of these categories carry authentication, permission, configuration or data-access evidence.

---

## R2 — SQL audit batch-start markers

**NO CHANGE - already live exactly as-is. Leave this processor alone.**

| Form field | Value |
|---|---|
| Short Description | Exclude SQL audit BATCH STARTED markers (paired COMPLETED event carries the signal) |
| Action | Exclude |
| Match | Body |
| Field | *(leave empty)* |

**Regex:**

```
"action_name":\s*"BATCH STARTED"
```

Cost: Zero. The paired COMPLETED event carries the signal; STARTED is a marker only.

---

## R3 — Azure Monitor platform metrics records

**ADD as a new processor.**

| Form field | Value |
|---|---|
| Short Description | Exclude Azure Monitor platform metrics records (no security evidence) |
| Action | Exclude |
| Match | Body |
| Field | *(leave empty)* |

**Regex:**

```
"timeGrain":\s*"PT
```

Cost: Zero. Platform metrics carry no security evidence. Often a large, overlooked volume contributor (a PT1M metrics stream was observed in this estate's feed list).

---

## R4 — OPTIONAL: session logout / connection teardown churn

**DO NOT ADD YET. Confirm the real action_name value in a live event first.**

| Form field | Value |
|---|---|
| Short Description | Exclude session logout / connection teardown churn |
| Action | Exclude |
| Match | Body |
| Field | *(leave empty)* |

**Regex:**

```
"action_name":\s*"(LOGOUT|DATABASE AUTHENTICATION LOGOUT|CONNECTION CLOSED)"
```

Cost: Near-zero, NOT zero. Logons are retained in full - only teardown is dropped. Marginal loss of session-duration context. Omit for a provably zero-cost set.

---

## ⚠️ Editing is NOT deploying

Saving a processor edit does **not** push it to SecOps. You must click **Rollout** (/ Sync).
Confirmed in practice on 22/08/2026: after adding a processor, the Chronicle-side
`updateTime` stayed at the old value until Rollout was clicked, at which point it moved
immediately. If `updateTime` hasn't changed, the rollout hasn't happened.

## Steps

1. Open the pipeline URL, **export/screenshot the current definition** (rollback).
2. Processor 1 → replace its **Regex** with R1. Leave Action=Exclude, Match=Body, Field empty.
3. **Add** a new "Filter by Regex" processor → fill in R3.
4. Leave processor 2 untouched. Do **not** add R4.
5. Save → sync / rollout.

## Pre-flight gates

- [ ] No live SecOps rule depends on `Blocks` or `Deadlocks` (new in R1) — §7.6
- [ ] Happy that `Errors` stays retained (deliberately not dropped)
- [ ] Change record / sign-off per the decision paper

## Verify after deploy

Before: `updateTime = 2026-08-20T10:35:01.605343Z`, **2** processors.
After:  `updateTime` = deploy time, **3** processors.

Then measure AZURE_SQL volume by `category`, and within `SQLSecurityAuditEvents` by
`action_name` + average event size. That sizes the real dent and shows the next lever.

---

## Why the routine-DML filter (D3) is not implementable here

Safely dropping routine DML needs three conditions ANDed:

```
action_name is a batch/RPC completion
AND statement matches SELECT|INSERT|UPDATE|DELETE
AND succeeded = true        <-- the guard preserving FAILED statements
```

One regex per processor, and RE2 has no lookahead, so that guard cannot be expressed.
A single-regex DML drop would also remove **failed** statements — destroying visibility of
probing, injection attempts and permission denials.

Mechanical reason, independent of the exfiltration/insider-threat argument, not to pursue D3
here. Close the volume gap with field pruning, dedup or asset-scoped filtering instead —
see `AZURE_SQL_FILTER_DESIGN.md`.
