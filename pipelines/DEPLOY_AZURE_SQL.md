# Deploying the AZURE_SQL filter changes

**How this pipeline works:** you add **exclude processors**, each with a **single bare regex**.
The UI generates the OTTL wrapper (`body != nil and IsString(body) and IsMatch(body, …)`) and all
escaping for you. So paste **only the regex** shown below — nothing else.

> The JSON spec is a **record**, not an uploadable file. Values below are generated from it.
> Do not retype them.

**Pipeline:** `Azure_SQL_Filter`
**Edit here:** https://app.bindplane.com/p/01KC4W80ECMCJ8QJ9AG85S9S5J/secops-pipelines/9c7b26bd-11f3-432f-a7df-a30b56a8955f
**Rollback:** current 2-processor definition is preserved in `azure_sql_filter.json` — screenshot/export before editing.

## Two rules of this UI model (they matter)

1. **One regex per processor.** You cannot AND two conditions inside a single processor.
2. **Multiple processors = OR.** Each processor drops independently.

Consequence: every rule below is a single self-contained regex. It is also why the
routine-DML filter (proposed D3) is **not implementable safely here** — see the end.

---

## The change: one edit, one addition

| Processor | Action |
|---|---|
| 1 — category exclude | **REPLACE** the regex (R1) — 6 → 11 categories |
| 2 — `BATCH STARTED` | **LEAVE ALONE** — already correct |
| *new* 3 | **ADD** R3 |
| *new* 4 | **DO NOT ADD YET** (R4) |


---

## R1 — non-security diagnostic / performance / health categories

- **Action:** EXCLUDE
- **Change:** REPLACE the existing processor 1 regex. Strict superset of the live 6 categories: 5 added, 0 removed.

**Regex to paste:**

```
"category":\s*"(DatabaseWaitStatistics|QueryStoreWaitStatistics|QueryStoreRuntimeStatistics|ResourceUsageStats|Timeouts|AutomaticTuning|WorkflowRuntime|Blocks|Deadlocks|SQLInsights|DatabaseInstances)"
```

Zero. None of these categories carry authentication, permission, configuration or data-access evidence.

---

## R2 — SQL audit batch-start markers

- **Action:** EXCLUDE
- **Change:** NO CHANGE - already live exactly as-is. Leave this processor alone.

**Regex to paste:**

```
"action_name":\s*"BATCH STARTED"
```

Zero. The paired COMPLETED event carries the signal; STARTED is a marker only.

---

## R3 — Azure Monitor platform metrics records

- **Action:** EXCLUDE
- **Change:** ADD as a new processor.

**Regex to paste:**

```
"timeGrain":\s*"PT
```

Zero. Platform metrics carry no security evidence. Often a large, overlooked volume contributor (a PT1M metrics stream was observed in this estate's feed list).

---

## R4 — OPTIONAL: session logout / connection teardown churn

- **Action:** EXCLUDE
- **Change:** DO NOT ADD YET. Confirm the real action_name value in a live event first.

**Regex to paste:**

```
"action_name":\s*"(LOGOUT|DATABASE AUTHENTICATION LOGOUT|CONNECTION CLOSED)"
```

Near-zero, NOT zero. Logons are retained in full - only teardown is dropped. Marginal loss of session-duration context. Omit for a provably zero-cost set.

---

## Steps

1. Open the pipeline URL above.
2. **Export/screenshot the current definition** (this is your rollback).
3. Processor 1 → replace its regex with **R1**. Keep the exclude action and `errorMode = IGNORE`.
4. **Add** a new exclude processor → paste **R3**. `errorMode = IGNORE`.
5. Leave processor 2 untouched. Do **not** add R4.
6. Save → sync / rollout.

## Pre-flight gates

- [ ] No live SecOps rule depends on `Blocks` or `Deadlocks` (new in R1) — §7.6
- [ ] Happy that `Errors` stays retained (deliberately not dropped)
- [ ] Change record / sign-off per the decision paper

## Verify after deploy

Before: `updateTime = 2026-08-20T10:35:01.605343Z`, **2** processors.
After:  `updateTime` = your deploy time, **3** processors.

Then measure: AZURE_SQL volume by `category`, and within `SQLSecurityAuditEvents`
by `action_name` plus average event size. That sizes the real dent and shows the next lever.

---

## Why the routine-DML filter (D3) is not implementable here

Dropping routine DML *safely* needs three conditions ANDed:

```
action_name is a batch/RPC completion
AND statement matches SELECT|INSERT|UPDATE|DELETE
AND succeeded = true        <-- the guard that preserves FAILED statements
```

With one regex per processor, and RE2 having no lookahead, that guard cannot be
expressed. A single-regex DML drop would also remove **failed** statements —
destroying visibility of probing, injection attempts and permission denials.

This is an independent, mechanical reason (on top of the exfiltration/insider-threat
argument) not to pursue D3 in this pipeline. Close the volume gap with field
pruning, dedup or asset-scoped filtering instead — see `AZURE_SQL_FILTER_DESIGN.md`.
