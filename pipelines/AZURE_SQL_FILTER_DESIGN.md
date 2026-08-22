# AZURE_SQL — drop filter set

> ## ⛔ STATUS: NOT DEPLOYED — FOR REVIEW ONLY
> These definitions have **not** been applied to any environment. The live pipeline
> `9c7b26bd-11f3-432f-a7df-a30b56a8955f` is **unchanged** and still runs the original
> 2 rules in [`azure_sql_filter.json`](./azure_sql_filter.json).
>
> Do not apply until: (a) this design is approved, (b) the §7.6 pre-implementation
> validation is complete, and (c) the open decisions below are closed.

**Governance basis:** Decision Paper *Filtering of AZURE_SQL*, 20/08/2026, issued & approved by Johann de Winnaar. Decision **FILTER HEAVILY**, Priority **P2**, implementation point **BindPlane**.

**Targets (§2, §12.1):** retain ~20% of ≈34.526 GB/day → ≈6.905 GB/day; save ≈27.621 GB/day ≈ 0.83 TB/month ≈ 10.08 TB/year.

**Approach:** drop-only. Every rule is a `filterProcessor` that removes a specific category of traffic named in §7.5 / §12.3. No allowlist/keep inversion — nothing is dropped unless a rule explicitly targets it.

Definition: [`azure_sql_filter_v2.json`](./azure_sql_filter_v2.json) · Live baseline: [`azure_sql_filter.json`](./azure_sql_filter.json)

---

## Deployable rules

| # | Drops | Maps to (§7.5/§12.3) | Basis |
|---|---|---|---|
| **D1** | Categories: `DatabaseWaitStatistics`, `QueryStoreWaitStatistics`, `QueryStoreRuntimeStatistics`, `ResourceUsageStats`, `Timeouts`, `AutomaticTuning`, `WorkflowRuntime`, `Blocks`, `Deadlocks`, `SQLInsights`, `DatabaseInstances` | Health telemetry; Performance monitoring | **Grounded** — `category` proven present in this feed |
| **D2** | `action_name = BATCH STARTED` | Expected application transactions | **Grounded** — already live |
| **D3** | Successful routine DML — `BATCH COMPLETED`/`RPC COMPLETED`/`TRANSACTION COMMITTED` where statement starts `SELECT`/`INSERT`/`UPDATE`/`DELETE`/`MERGE` **and** `succeeded=true` | Routine SELECT/INSERT/UPDATE/DELETE; Normal application activity; Routine business transactions | Confirm `statement` field name |
| **D4** | `DATABASE AUTHENTICATION SUCCEEDED`, `LOGIN SUCCEEDED`, `CONNECTION CLOSED` | Successful routine connections | Confirm values present |

**D3 and D4 are the volume levers.** D1/D2 alone will not approach 80%, because most AZURE_SQL volume is routine DML inside `SQLSecurityAuditEvents`.

### Built-in safety guards
- **D3 only drops `succeeded=true`.** Failed statements — permission denials, probing, injection attempts — are **never** dropped.
- **D4 only drops successes.** `LOGIN FAILED` / `DATABASE AUTHENTICATION FAILED` are untouched (§7.4 authentication failures).
- **D1 does not touch `SQLSecurityAuditEvents`**, so no audit event is lost to the category drops.
- All rules use `errorMode: IGNORE` — an unparseable record is **not** dropped.

---

## Rules still needing field values

These are named in §7.5/§12.3 but cannot be written without the actual field values in this estate. Per §12.4.3 they are recorded as **unsupported rather than invented** — no guessed rule has been added.

| # | Would drop | Needs |
|---|---|---|
| D5 | Service-account / normal application traffic | Confirmed `server_principal_name` / `application_name` values |
| D6 | ORM-generated workload | Confirmed ORM `application_name` (e.g. framework client string) |
| D7 | Scheduled reporting + ETL processing | Confirmed reporting/ETL principal or app names |
| D8 | Backup / replication / synchronisation | Confirmed identifying field; see conflict below |

To unlock these: sample production events and record the identifying field/value per §12.5, then add one drop rule each.

---

## Decisions needed

1. **Backup contradiction.** §7.5 lists *"Backup operations"* as FILTER, but restore activity is a recognised tamper/exfiltration vector. Confirm: drop scheduled backups only, or backup **and** restore?
2. **`Errors` category** — deliberately **not** dropped in D1. Drop as operational noise, or retain for investigation value?
3. **`Blocks` / `Deadlocks`** — included in D1. Confirm no approved detection depends on them (§7.6).
4. **Consequence to accept:** D3 drops *successful* `SELECT`, which is also where bulk-export / large-result-set evidence would live. §7.4 lists those as retain-worthy, but they have no distinguishing field in this feed (no rows-returned/volume field), so they cannot be exempted. Either accept the loss, or add a narrower carve-out once a volumetric field is identified.

---

## Validation (§7.6, §12.6)

**Before:** capture representative events per category · confirm no active detection relies on D1–D4 targets · re-confirm the 34.526 GB/day baseline.

**After:** confirm retained events still searchable · confirm routine DB traffic stopped · **measure actual reduction** against the 0.83 TB/month estimate · confirm detections still function · record final logic + evidence in the SIEM engineering record.

> Expected reduction is **not** asserted here — it must be measured. If D1–D4 fall short of 80%, close the gap with D5–D8 once field values are confirmed, rather than broadening D3.

## Deployment note

These are **Google SecOps `logProcessingPipelines`** (Chronicle API), authored via BindPlane's SecOps Pipelines UI — not BindPlane processor resources. Apply by updating pipeline `9c7b26bd-11f3-432f-a7df-a30b56a8955f` so history/metadata is preserved. `scripts/apply.sh` (BindPlane CLI) does **not** apply these.
