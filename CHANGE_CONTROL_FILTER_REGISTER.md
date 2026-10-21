# Change Control — Log Filter Register
## BindPlane → Google SecOps ingestion filters

| | |
|---|---|
| **Document ID** | CC-SECOPS-FLT-001 |
| **Version / status** | 0.3 — DRAFT — **not ready for approval (see §0)** |
| **Date** | 21 Oct 2026 |
| **Platform** | BindPlane (`app.bindplane.com`) · Google SecOps UK (project `01KC4W80ECMCJ8QJ9AG85S9S5J`) |
| **SecOps tenant** | GCP project `721279881207` · `europe-west2` · customer `c98f7d82-a2a4-45a1-a96a-a4dee6cf39fd` |
| **Change type** | Pre-ingestion log filtering (drop / redact) to control SecOps ingestion volume |
| **Ingestion target** | ≤ 4.5 TB/month |
| **Change owner** | _[to be completed]_ |
| **Security approver** | _[to be completed]_ |

---

## 0. Live inventory check — 21 Oct 2026 (BindPlane API)

The live instance was queried through the BindPlane API on 21 Oct 2026. **Rule content is not available through the API** (GraphQL introspection is disabled and the pipeline summary exposes only metadata), so the rules in §4 are as last exported (20–24 Aug 2026) and **have not been re-verified**. The pipeline inventory below is current.

**The live instance has 15 SecOps pipelines. This register's §4 covers 5 of them, and several have changed since the export it is based on.**

| Pipeline | Log type | Created | Last updated | Register coverage |
|---|---|---|---|---|
| AWS_Filter | _(none)_ | 14 Aug | **27 Aug** | §4.2 — **changed after export; re-verify** |
| AWS_Filter2 | _(none)_ | 17 Aug | **26 Aug** | §4.3 — **changed after export; re-verify** |
| ZSCALER_Filter | UDM | 21 Aug | **25 Aug** | §4.4 — **changed after export; log type now UDM; re-verify** |
| Microsoft_Insights_Components → now `MICROSOFT_INSIGHTS_COMPONENTS` | MICROSOFT_INSIGHTS_COMPONENTS | 25 Aug | 25 Aug | §4.5 — **pipeline recreated 25 Aug; re-verify** |
| `Azure_SQL_Filter` | AZURE_SQL | 18 Aug | — | §4.1 — **NOT PRESENT in live list; do not rely on F-01 to F-04** |
| SQL_Include | AZURE_SQL | 25 Aug | 25 Aug | **Not in register — rules unknown** |
| ZSCALER_WEBPROXY_Filter | ZSCALER_WEBPROXY | 27 Aug | **1 Sep** | **Not in register — rules unknown** |
| ZSCALER_ZPA_Filter | ZSCALER_ZPA | 24 Aug | 26 Aug | **Not in register — corresponds to P-03; status unknown** |
| ZSCALER_DNS_Filter | ZSCALER_DNS | 25 Aug | 26 Aug | **Not in register — corresponds to P-05; status unknown** |
| ZSCALER_FIREWALL_Filter | ZSCALER_FIREWALL | 25 Aug | 27 Aug | **Not in register — corresponds to P-06; status unknown** |
| AZURE_ACTIVITY_Filter | AZURE_ACTIVITY | 24 Aug | 28 Aug | **Not in register — rules unknown** |
| Azure_Gateway_Filter | AZURE_GATEWAY | 24 Aug | 26 Aug | **Not in register — rules unknown** |
| Azure_Storage_Audit_Filter | AZURE_STORAGE_AUDIT | 26 Aug | 26 Aug | **Not in register — corresponds to P-07; status unknown** |
| AWS_VPC_Flow | AWS_VPC_FLOW | 26 Aug | 26 Aug | **Not in register — corresponds to P-04; status unknown** |
| Azure_Service_Bus_logs | MICROSOFT_SERVICEBUS_NAMESPACES | 26 Aug | 26 Aug | **Not in register — falls under P-11; status unknown** |
| AZURE_WVD_MANAGEMENT | AZURE_WVD_MANAGEMENT | 28 Aug | 28 Aug | **Not in register — rules unknown** |

**Consequence for this document:** the "Proposed" status of P-01, P-03 to P-07 and P-11, and the "Live" status of F-01 to F-04 and F-11, cannot be relied on until the pipeline definitions are exported. Treat this register as **NOT READY FOR APPROVAL** until the export in Appendix A is complete for all 15 pipelines.

---

## 1. Purpose and scope

This document is the register of every filter applied to log feeds passing through BindPlane into Google SecOps. For each filter it records the configuration, current status, rationale, conditions of operation and residual risk, so that each can be approved, reviewed, changed or rolled back under change control.

**Scope:** the 15 SecOps pipelines listed in §0. Detailed filter entries (§4) currently exist for 5 of them, based on the 20–24 Aug export; the remaining 10 need their definitions exported.

**Status key:** **LIVE** = in force · **PROPOSED** = not deployed, awaiting conditions and approval · **SUPERSEDED / REJECTED** = will not be deployed.

---

## 2. Filter status summary

### 2.1 Live filters

| Ref | Pipeline | Log source | Filter | Type | Status | Last changed | Est. volume impact (TB/mo) |
|---|---|---|---|---|---|---|---:|
| F-01 | Azure_SQL_Filter | AZURE_SQL | Drop `BATCH STARTED` markers | Exclude | LIVE | 20 Aug 2026 | ~5.74 combined (F-01 to F-04) |
| F-02 | Azure_SQL_Filter | AZURE_SQL | Drop 11 diagnostic / performance categories | Exclude | LIVE | 22 Aug 2026 | ↑ |
| F-03 | Azure_SQL_Filter | AZURE_SQL | Drop Azure Monitor platform metrics | Exclude | LIVE | 22 Aug 2026 | ↑ |
| F-04 | Azure_SQL_Filter | AZURE_SQL | Redact PII presets + SQL `statement` text | Redact | LIVE | 22 Aug 2026 | ↑ |
| F-05 | AWS_Filter | AWS_CLOUDTRAIL | 3 enumerated read-only `eventName` lists (~800 names) | Exclude | LIVE | 19 Aug 2026 | ~5.20 combined (F-05 to F-07) |
| F-06 | AWS_Filter | AWS_CLOUDTRAIL | Rule A — drop `readOnly:true` | Exclude | LIVE | 22 Aug 2026 | ↑ |
| F-07 | AWS_Filter | AWS_CLOUDTRAIL | Rule B — drop AWS-service `invokedBy` | Exclude | LIVE | 22 Aug 2026 | ↑ |
| F-08 | AWS_Filter2 | AWS_WAF | Drop monitoring-agent User-Agents (ALB) | Exclude | LIVE | 20 Aug 2026 | minor |
| F-09 | ZSCALER_Filter | ZSCALER_WEBPROXY | Z0 — drop Darktrace sensor traffic | Exclude | LIVE | 21 Aug 2026 | minor |
| F-10 | ZSCALER_Filter | ZSCALER_WEBPROXY | Z1 — drop allowed / no-threat Microsoft traffic | Exclude | LIVE | 22 Aug 2026 | ~0.4 |
| F-11 | Microsoft_Insights_Components | MICROSOFT_INSIGHTS_COMPONENTS | Source removed entirely | Remove | LIVE | 20–21 Aug 2026 | ~0.83 |

### 2.2 Proposed filters (not in force)

| Ref | Pipeline | Log source | Filter | Status | Est. volume impact (TB/mo) | Blocking condition |
|---|---|---|---|---|---:|---|
| P-01 | ZSCALER_Filter | ZSCALER_WEBPROXY | Category-based allowed / no-threat drop | PROPOSED | ~0.7–1.4 | Confirm current deployed state; security acceptance |
| P-02 | AWS_Filter2 | AWS_WAF | Drop `action":"ALLOW"` (keep BLOCK / COUNT) | PROPOSED | ~1.49 | Sample event + recorded sign-off |
| P-03 | _(new)_ | ZSCALER_ZPA | Drop allowed / no-threat | PROPOSED | ~0.09 | Confirm feed fields |
| P-04 | _(new)_ | AWS_VPC_FLOW | Drop ACCEPT, keep REJECT | PROPOSED | ~0.12 | Sample event |
| P-05 | _(new)_ | ZSCALER_DNS | Drop trusted-domain resolutions | PROPOSED | ~0.09 | Confirm field name |
| P-06 | _(new)_ | ZSCALER_FIREWALL | Drop allowed / permitted flows | PROPOSED | ~0.08 | Confirm value |
| P-07 | _(new)_ | AZURE_STORAGE_AUDIT | Drop routine read / list operations | PROPOSED | ~0.07 | Confirm field |
| P-08 | _(new)_ | AZURE_DOCUMENTDB | Drop routine data-plane reads | PROPOSED | ~0.05 | Confirm field |
| P-09 | _(new)_ | AZURE_WAF | Drop ALLOW, keep BLOCK | PROPOSED | ~0.02 | Sample event; regex correction |
| P-10 | _(new)_ | GCP_CLOUDAUDIT | Drop read-only / DATA_READ | PROPOSED | ~0.01 | Confirm structure |
| P-11 | _(new)_ | AZURE_DATAPLANE, NSG_FLOW, FIREWALL, ServiceBus, Barracuda | Drop request / allow / read noise | PROPOSED | ~0.10 | Per-source assessment |

### 2.3 Superseded / rejected

| Ref | Item | Status | Reason |
|---|---|---|---|
| X-01 | Zscaler Z2 (Google), Z3 (Apple), Z4 (CDN) domain rules | SUPERSEDED | Replaced by category-based rule P-01 |
| X-02 | Azure SQL: drop routine successful DML | REJECTED | Removes exfiltration / insider-threat detection; cannot safely be expressed as a single regex |
| X-03 | Azure SQL: drop successful logins | REJECTED | Negligible saving; removes failure→success detection |
| X-04 | Azure SQL: drop logout / teardown events | NOT IMPLEMENTED | `action_name` value unconfirmed |
| X-05 | Azure SQL: drop `Errors` category | NOT IMPLEMENTED | Retained pending decision |

---

## 3. Standing conditions (apply to every filter)

| # | Condition |
|---|---|
| SC-1 | **Subtractive only.** Filters are *Filter by Regex* processors (Action `Exclude`, Match `Body`, Field empty), except F-04 (redaction). |
| SC-2 | **Fail-safe.** `errorMode: IGNORE` — a record that cannot be evaluated is kept. A faulty regex matches nothing; it does not drop unrelated data. |
| SC-3 | **Dropped data is unrecoverable** in SecOps and cannot be retro-hunted. Source-side retention is the only fallback and must be confirmed per source. |
| SC-4 | **A change is live only after Rollout.** Saving a processor does not deploy it. |
| SC-5 | **Verify by exporting the pipeline JSON**, not by `updateTime`. Confirm the deployed regex matches the approved regex exactly. |
| SC-6 | **Silent-failure monitoring:** per-log-type volume floor alert; a canary event per retained category; rule-firing baseline before and after any change. |
| SC-7 | **Format dependency:** Zscaler rules assume field order `action → hostname → threatcategory`. A feed format change causes the rule to stop matching (no data loss, but no saving); re-verify after any feed change. |
| SC-8 | **New filters** require: a real sample event, regex tested against keep and drop cases, a named approver and a rollback export taken before the change. |
| SC-9 | Filters that trade detection capability for volume are **policy decisions** and require a recorded, accountable approval. |
| SC-10 | Each filter is reviewed at least quarterly and whenever detection content or source format changes. _[confirm cadence]_ |

**Standard rollback:** open the pipeline in BindPlane → remove or revert the processor → Save → **Rollout** → export the JSON to confirm. This stops further drops; it does **not** restore events already dropped. Pre-change definitions are held in this repository (`pipelines/`).

---

## 4. Live filter configuration

### 4.1 Azure_SQL_Filter — log type `AZURE_SQL`

| | |
|---|---|
| **Pipeline ID** | `9c7b26bd-11f3-432f-a7df-a30b56a8955f` |
| **Stream** | log type `AZURE_SQL` |
| **Processors (in order)** | 1. Exclude `BATCH STARTED` · 2. Exclude metrics · 3. Exclude diagnostic categories · 4. Redact |
| **Governance basis** | Decision Paper *Filtering of AZURE_SQL*, 20/08/2026 (J. de Winnaar) |

#### F-01 — Drop `BATCH STARTED` markers
| | |
|---|---|
| **Regex** | `"action_name":\s*"BATCH STARTED"` |
| **Rationale** | The paired COMPLETED event carries the audit signal; STARTED is a marker only. |
| **Retained** | All other audit events: batch / RPC completion, logons, permission changes, failures. |
| **Conditions** | Paired COMPLETED events must continue to arrive (canary). |
| **Residual risk** | Low. |

#### F-02 — Drop non-security diagnostic / performance categories
| | |
|---|---|
| **Regex** | `"category":\s*"(DatabaseWaitStatistics\|QueryStoreWaitStatistics\|QueryStoreRuntimeStatistics\|ResourceUsageStats\|Timeouts\|AutomaticTuning\|WorkflowRuntime\|Blocks\|Deadlocks\|SQLInsights\|DatabaseInstances)"` |
| **Rationale** | Performance and health telemetry; carries no authentication, permission, configuration or data-access evidence. |
| **Retained** | `SQLSecurityAuditEvents`; `Errors`; any new or unknown category. |
| **Conditions** | Cyber Defence to confirm no approved detection depends on `Blocks` or `Deadlocks` (BL-03). Decision on `Errors` (BL-04). |
| **Residual risk** | Low. |

#### F-03 — Drop Azure Monitor platform metrics
| | |
|---|---|
| **Regex** | `"timeGrain":\s*"PT` |
| **Rationale** | Platform metrics records carry no security evidence. |
| **Retained** | All records without the metrics fingerprint. |
| **Conditions** | Confirm no audit record legitimately contains this string (e.g. within a SQL statement). |
| **Residual risk** | Low. |

#### F-04 — Redact sensitive data
| | |
|---|---|
| **Configuration** | Redact processor, censor with asterisks, all types. 14 built-in presets (IBAN, MAC, payment card, date, email, IPv4, IPv6, phone ×2, SSN, city/state, street address, ZIP, UUID) plus custom pattern `"statement":"[^"]*"`. |
| **Rationale** | Reduces event size by removing SQL statement text while keeping the event skeleton; reduces personal data held in SecOps. |
| **Retained (intended)** | Principal, client IP, database, object, action, outcome, timestamp. |
| **Conditions** | **Output verification outstanding (BL-01).** Inspect a live event and confirm (1) only the statement value is blanked, key label intact; (2) client IP, principal identity, object identifiers and timestamps are preserved — the presets apply to the whole body; (3) SecOps parsing is unaffected. If (2) fails, reduce the processor to the custom statement pattern only. |
| **Residual risk** | **Medium until BL-01 closed.** Statement text is no longer searchable in SecOps; Azure-side audit retention is the fallback. |

---

### 4.2 AWS_Filter — AWS CloudTrail

| | |
|---|---|
| **Pipeline ID** | `c072e6b7-0690-419c-82ca-901b7ab2bc3f` |
| **Stream** | feed `2ff7b983-0b01-4303-9848-4ce9b3db2bd3` |
| **Processors (in order)** | 1–3. Enumerated read-only `eventName` lists · 4. Rule A (`readOnly:true`) · 5. Rule B (`invokedBy`) |
| **Basis** | CloudTrail separates "who looked" (read) from "who changed something" (write). Attacks are predominantly writes, so all writes are kept. Reconnaissance detection relies on GuardDuty. |

#### F-05 — Enumerated read-only `eventName` lists
| | |
|---|---|
| **Configuration** | Three Filter by Regex processors listing ~800 read-only event names, including KMS `Encrypt` / `GenerateDataKey`. **Regexes to be attached as Appendix A.** |
| **Rationale** | Original volume reduction of high-frequency read events. |
| **Conditions** | Attach exported regexes. Record the approver of the KMS drop decision. Largely redundant with F-06; may be simplified later under a separate change. |
| **Residual risk** | Low–Medium (KMS key-usage visibility is removed). |

#### F-06 — Rule A: drop `readOnly:true`
| | |
|---|---|
| **Regex** | `"readOnly"\s*:\s*true` |
| **Rationale** | Uses AWS's own read / write classification instead of a maintained list. |
| **Retained** | All `readOnly:false` events (create, modify, delete, permission changes). |
| **Conditions** | (1) GuardDuty ingestion confirmed active. (2) Cyber Defence to confirm no SecOps rule or hunt relies on read events (e.g. secret / parameter retrieval, STS). |
| **Residual risk** | **Medium.** Credential-access and reconnaissance reads are not held in SecOps. Compensating control: GuardDuty; AWS-side CloudTrail retention. |

#### F-07 — Rule B: drop AWS-service-invoked events
| | |
|---|---|
| **Regex** | `"invokedBy"\s*:\s*"[a-z0-9.\-]+\.amazonaws\.com"` |
| **Rationale** | AWS services calling other AWS services are automation, not users. |
| **Retained** | Events with no AWS-service `invokedBy` (direct user, role or external callers). |
| **Conditions** | Approver to accept that this rule also drops **write** events performed by an AWS service on a principal's behalf (e.g. CloudFormation). The originating API call by the principal is still retained. |
| **Residual risk** | Medium–Low. |

---

### 4.3 AWS_Filter2 — AWS WAF

| | |
|---|---|
| **Pipeline ID** | `6f17d9b9-8874-4c5b-9a54-eca796841abc` |
| **Stream** | feed `4cc610fa-2e49-467b-a573-00a1cdcd6480` |
| **Processors** | 1. Monitoring User-Agent exclusion (no ALLOW filter — see P-02) |

#### F-08 — Drop monitoring-agent User-Agents
| | |
|---|---|
| **Rule** | Exclude where `httpSourceName":"ALB"` and the `User-Agent` value begins `ELB-HealthChecker/`, `Blackbox Exporter/`, `Grafana/` or `Java-EurekaClient[-Replication]/v` followed by a version. |
| **Rationale** | Health-check and monitoring probes are high-volume, repetitive and have no security value. |
| **Retained** | All other traffic and all non-ALB sources. |
| **Conditions** | Approver to accept that the rule is not action-aware and has no source-IP guard: a request using one of these User-Agents is dropped whether allowed or blocked, so the User-Agent can be spoofed to avoid logging. Optional hardening: restrict to ALLOW or internal source ranges. |
| **Residual risk** | Medium–Low. |

---

### 4.4 ZSCALER_Filter — ZSCALER_WEBPROXY

| | |
|---|---|
| **Pipeline ID** | `7d023b21-3b13-4580-9174-a86b14dace06` |
| **Stream** | feed `02d280ff-d19e-494f-8319-81a8545fdf42` (web proxy only; filters are per feed — ZPA, DNS and Firewall feeds are not covered) |
| **Processors (in order)** | 1. Z0 Darktrace · 2. Z1 Microsoft |
| **Policy position** | Blocked Zscaler traffic is reviewed in the Zscaler console and is not required in SecOps. No blocked-traffic drop rule is configured. |

#### F-09 — Z0: Darktrace sensor traffic
| | |
|---|---|
| **Regex** | `(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.darktracesensor\.com".*?"threatcategory"\s*:\s*"None")` |
| **Rationale** | Own security tooling; allowed, no threat, no investigative value. |
| **Retained** | Blocked, threat-flagged and all other hosts. |
| **Conditions** | SC-7 field-order dependency. |
| **Residual risk** | Low. |

#### F-10 — Z1: allowed / no-threat Microsoft traffic
| | |
|---|---|
| **Regex** | `(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(microsoft\|office\|office365\|windows\|windowsupdate\|azure\|azureedge\|msftconnecttest\|msedge\|live\|microsoftonline)\.(com\|net)".*?"threatcategory"\s*:\s*"None")` |
| **Rationale** | Updates, Office 365, Windows telemetry and Azure endpoints make up a large share of proxy volume. Dropped only when **all three** are true: Allowed, trusted domain at the end of the hostname, and `threatcategory=None`. Look-alike domains (e.g. `microsoft.com.attacker.ru`) are retained. |
| **Retained** | Blocked traffic; any threat category; unknown and look-alike domains. |
| **Conditions** | Approver to accept that `windows.net` and `azureedge.net` host third-party content (e.g. `*.blob.core.windows.net` storage accounts), which this rule drops when Zscaler rates it `None`; or narrow the domain list. SC-7 field-order dependency. |
| **Residual risk** | **Medium.** Malicious content hosted on Microsoft infrastructure and rated `None` is not visible in SecOps. Compensating control: Zscaler console; endpoint telemetry. |

---

### 4.5 Microsoft_Insights_Components

| | |
|---|---|
| **Pipeline ID** | `54d1435e-1c44-44f3-a581-ee7ff2a83448` |
| **Stream** | log type `MICROSOFT_INSIGHTS_COMPONENTS` |

#### F-11 — Source removed entirely
| | |
|---|---|
| **Rationale** | Volume of ~27 GB/day (~0.83 TB/month). _[Security rationale to be stated by the owner — application performance telemetry; confirm no detection depends on it.]_ |
| **Conditions** | Attach the pipeline definition (Appendix A). Zero ingestion is intentional for this log type — exempt it from the SC-6 volume-floor alert and record the exception. |
| **Residual risk** | Low–Medium pending owner confirmation. |

---

## 5. Proposed filters

Not in force. Each requires its blocking condition cleared and approval before deployment. Paste-ready regexes: `pipelines/REMAINING_TARGETS_SPEC.md`.

| Ref | Proposed rule | Rationale | Conditions | Residual risk |
|---|---|---|---|---|
| **P-01** Zscaler category rule | Exclude where `action=Allowed`, `threatcategory=None` and `category_details` is one of: Business and Economy; Other Business and Economy; Exception Dynatrace; EMIS SSL Bypass; EMIS – AWS Cloud Connector Whitelist; EMIS GitHub Runners Whitelist; AAA_SSL_Microsoft_Windows_Endpoint_Optimization; AAA_SSL_Apple_Domains; Zscaler Proxy IPs | Category-based, self-maintaining, uses the organisation's own EMIS whitelists; supersedes domain rules X-01. | **Confirm whether currently deployed** by exporting `ZSCALER_Filter`. Security approver accepts that *Business and Economy* is a broad third-party category. EMIS whitelist categories have a named owner. SC-7. | Medium |
| **P-02** AWS WAF — drop ALLOW | `"action"\s*:\s*"ALLOW"` | Largest remaining reduction (~75% of WAF volume); keeps every BLOCK and COUNT. | **Mandatory:** one real WAF event confirming the `action` field / value; recorded sign-off (WAF protects public-facing apps); acceptance that allowed attacks which evade WAF rules are not visible in SecOps and allowed requests cannot be retro-hunted; consider exempting sensitive applications. | Medium–High |
| **P-03** ZPA | `(?s:"action"\s*:\s*"Allowed".*?"threatcategory"\s*:\s*"None")` | Same pattern as web proxy. | Confirm ZPA field names. As written this drops allowed access to **any** application; add a hostname clause to retain sensitive applications. | Medium |
| **P-04** AWS VPC Flow | JSON: `"action"\s*:\s*"ACCEPT"` · text: `\sACCEPT\s+OK\s*$` | Flow logs are mostly ACCEPT; all REJECT retained. | One sample to choose the format. Consider limiting the drop to known-good ranges / ports, since accepted flows evidence exfiltration and lateral movement. | Medium |
| **P-05** Zscaler DNS | Drop queries to `microsoft`, `windows`, `google`, `googleapis`, `apple`, `icloud`, `akamai`, `cloudflare` (`.com` / `.net`) | Trusted-domain resolutions. | Confirm DNS domain field name; consider adding an action / threat guard. | Low–Medium |
| **P-06** Zscaler Firewall | `"action"\s*:\s*"(Allow\|Allowed\|Permitted)"` | Routine permitted flows. | Confirm allowed-value string. Drops all allowed flows, not only routine ones. | Medium |
| **P-07** Azure Storage Audit | Drop `OperationName` in GetBlob, GetBlobProperties, GetBlobServiceProperties, ListBlobs, GetContainerProperties, GetContainerACL, HeadBlob, GetBlobMetadata, ListContainers | Routine reads; writes, deletes and permission changes retained. | Confirm field name and casing. Consider retaining `GetBlob` (mass-download / exfiltration signal) and dropping list / property operations only. | Medium |
| **P-08** Azure DocumentDB | `"OperationName"\s*:\s*"(Query\|ReadFeed\|Get\|Read)"` | Routine data-plane reads; control-plane and authentication retained. | Confirm field and values. | Medium |
| **P-09** Azure WAF | `"action_s"\s*:\s*"Allow"` | As P-02. | Sample event. **Regex requires correction:** if the value is `Allowed`, this expression will not match it. Retain Blocked / Matched. | Medium |
| **P-10** GCP CloudAudit | `methodName` ending `.get`, `.list`, `.aggregatedList` on `AuditLog` | DATA_READ noise; ADMIN_ACTIVITY retained. | Confirm structure; prefer filtering by log type. | Low–Medium |
| **P-11** Azure DataPlane / NSG Flow / Firewall / ServiceBus / Barracuda | No rule drafted | Request / allow / read noise. | Per-source assessment before any rule is drafted. | To be assessed |

---

## 6. Ingestion position

| | TB/month |
|---|---:|
| Pre-filtering baseline | ~19.9–21 |
| Projected with live filters | ~6 (range 6–10; weekday measurement outstanding — BL-02) |
| Projected with P-02 | ~5.5 |
| Projected with full proposed schedule | ~4.7 |
| **Target** | **4.5** |

Figures are estimates. Reaching the target with the proposed schedule is marginal. Any further reduction would require removing detection capability (e.g. X-02, a blanket Zscaler allow-drop, further CloudTrail write reductions) and must be taken as an explicit, recorded policy decision (SC-9), not as an engineering default.

---

## 7. Items to confirm before approval

| # | Item | Owner |
|---|---|---|
| 1 | Reconcile this register with the live instance (export all five pipelines) and confirm status of P-01 | Change owner |
| 2 | Attach missing configuration exports (Appendix A): F-05 regexes, F-11 pipeline definition | Change owner |
| 3 | BL-01 — verify F-04 redaction output, including that client IP and principal identity are retained | Change owner |
| 4 | BL-03 / BL-04 — Cyber Defence confirmation on `Blocks`, `Deadlocks`, `Errors` | Cyber Defence |
| 5 | Security acceptance of residual risk on F-06, F-07, F-08, F-10 (see §4) | Security approver |
| 6 | BL-02 — weekday volume measurement | Change owner |
| 7 | Azure SQL open decisions: backup vs restore filtering; Azure-side audit retention retrievable in incident timeframes; patient / sensitive data in scope | Cyber Defence / Cloud Eng / DPO |
| 8 | BL-06 — rotate BindPlane API keys shared during setup | Change owner |
| 9 | BL-08 — confirm single vs multiple Zscaler feeds | Change owner |

---

## 8. Approval

| Role | Name | Decision | Date | Signature |
|---|---|---|---|---|
| Change owner | | | | |
| Security / Cyber Defence | | | | |
| Cloud / platform engineering | | | | |
| Information governance / DPO | | | | |

**Decision key:** Approve · Approve with conditions · Reject
**Conditions attached to approval:** _[to be completed]_

---

## Appendix A — Configuration exports to attach

Export the pipeline JSON from `https://app.bindplane.com/p/01KC4W80ECMCJ8QJ9AG85S9S5J/secops-pipelines` for **all 15 pipelines** listed in §0 (the rules cannot be read through the API). Priority order:

| Priority | Pipelines | Why |
|---|---|---|
| 1 | `SQL_Include`, `ZSCALER_WEBPROXY_Filter`, `ZSCALER_Filter`, `AWS_Filter`, `AWS_Filter2` | Changed after the export this register is based on, or replace documented filters |
| 2 | `ZSCALER_ZPA_Filter`, `ZSCALER_DNS_Filter`, `ZSCALER_FIREWALL_Filter`, `AWS_VPC_Flow`, `Azure_Storage_Audit_Filter` | Correspond to proposals P-03 to P-07 — may already be live |
| 3 | `AZURE_ACTIVITY_Filter`, `Azure_Gateway_Filter`, `Azure_Service_Bus_logs`, `AZURE_WVD_MANAGEMENT`, `MICROSOFT_INSIGHTS_COMPONENTS` | Not documented in this register |

Also confirm what happened to `Azure_SQL_Filter` (absent from the live list) and whether `SQL_Include` replaces it.

## Appendix B — Configuration references in this repository

| Pipeline | Reference |
|---|---|
| Azure_SQL_Filter | `pipelines/azure_sql_filter_LIVE_20260822.json` (current); `pipelines/azure_sql_filter.json` (original); `pipelines/AZURE_SQL_FILTER_DESIGN.md`; `pipelines/DEPLOY_AZURE_SQL.md` |
| AWS_Filter | `pipelines/aws_cloudtrail_filter.json`; `pipelines/DEPLOY_AWS_CLOUDTRAIL.md` |
| AWS_Filter2 | `pipelines/aws_waf_filter_LIVE.json` |
| ZSCALER_Filter | `pipelines/zscaler_filter.json`; `pipelines/zscaler_filter_category_PROPOSED.json`; `pipelines/DEPLOY_ZSCALER.md` |
| Proposed filters | `pipelines/REMAINING_TARGETS_SPEC.md` |
