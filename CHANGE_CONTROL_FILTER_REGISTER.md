# Change Control — BindPlane / Google SecOps Log Filter Register

| | |
|---|---|
| **Document ID** | CC-SECOPS-FLT-001 |
| **Version / status** | 0.1 — DRAFT for review and approval |
| **Date prepared** | 21 Oct 2026 |
| **Evidence cut-off** | Repo state at 24 Aug 2026 (last commit `ba9df7e`). **Not re-verified against the live instance — see §1.** |
| **Instance / project** | `app.bindplane.com` · Google SecOps UK (`01KC4W80ECMCJ8QJ9AG85S9S5J`) |
| **SecOps tenant** | project `721279881207` · `europe-west2` · customer `c98f7d82-a2a4-45a1-a96a-a4dee6cf39fd` |
| **Change type** | Log-ingestion volume reduction (drop / redact before SecOps ingest) |
| **Objective** | Reduce SecOps ingestion from ~19.9–21 TB/month to ≤ 4.5 TB/month |
| **Change owner** | _[to be completed]_ |
| **Security approver** | _[to be completed]_ |

---

## 1. Read this before approving

This register was assembled from the repository (pipeline JSON exports, deployment guides, commit history). I have no access to the live BindPlane/SecOps instance from here, so **nothing below has been re-checked against live state since 24 Aug 2026.** Run `inventory/export-filters.sh` and reconcile before this goes to the approver.

Items that need a decision or evidence before sign-off:

| # | Matter | Why it matters | Needed |
|---|---|---|---|
| A1 | **Zscaler category rule — status is contradictory in the repo.** Commit `37948c7` said it was live; commit `ba9df7e` (later, "authoritative snapshot") says an earlier note "wrongly marked it live off a stale updateTime" and it is **not deployed**. The `_LIVE.json` file named in the earlier commit no longer exists. | Register cannot say whether it is in force. Treated here as **NOT DEPLOYED (P-01)**. | Fresh pipeline JSON export of `ZSCALER_Filter` |
| A2 | **Azure SQL redaction scope.** The processor applies the built-in preset patterns (IPv4/IPv6, email, UUID, date, phone, postcode, street address, card, IBAN, MAC) to the **whole body**, not only the `statement` value. Tested: the IPv4 and email presets match `client_ip` and `server_principal_name`-style values. Open item BL-01 only checks that the `"statement":` *label* survives. | If client IP / principal identity are blanked, the "who touched what from where" evidence the design relies on (`AZURE_SQL_FILTER_DESIGN.md` §Step 3) is lost. | Inspect one live post-redaction event for client IP, principal, object, timestamp (extends BL-01) |
| A3 | **CloudTrail Rule B drops write events.** It drops any event with an AWS-service `invokedBy`, regardless of `readOnly`. Tested: a `readOnly:false` event invoked by `cloudformation.amazonaws.com` is dropped by Rule B. `DEPLOY_AWS_CLOUDTRAIL.md` states "all writes are kept", which is not strictly true. | Service-chained changes made on a principal's behalf are not in SecOps. The originating API call by the principal is still logged. | Approver acceptance (recorded in F-07) |
| A4 | **CloudTrail Rule A drops all `readOnly:true` events**, including reads that matter for credential-access detection (e.g. secret/parameter retrieval, STS calls — classification per event to be confirmed). The justification "recon is covered by GuardDuty" is an assumption. | Possible detection gap | Confirm GuardDuty is ingested and list SecOps rules that key on read events |
| A5 | **Zscaler Z1 hostname wildcards are broad.** `windows.net` and `azureedge.net` are hosting namespaces. Tested: `evil-acct.blob.core.windows.net` and `x.azureedge.net` (Allowed, threatcategory None) are dropped. | Attacker-controlled content hosted on Microsoft infrastructure is not visible when Zscaler rates it `None` | Approver acceptance, or narrow the rule |
| A6 | **AWS WAF monitoring-UA rule is not action-aware and is spoofable.** It drops by `User-Agent` only (ALB source). Tested: a request with UA `ELB-HealthChecker/2.0 sqlmap` is dropped, and the rule has no end anchor. It drops BLOCKED requests too. | An attacker setting a monitoring UA is invisible in SecOps | Approver acceptance, or add action/IP guard |
| A7 | **Artefacts missing from the repo:** (a) the three enumerated CloudTrail `eventName` rules (~800 names); (b) the `Microsoft_Insights_Components` pipeline definition; (c) the Zscaler category rule export. | Cannot evidence exactly what is in force | Attach exports as Appendix |
| A8 | **Pre-flight gates were open when Azure SQL R1 was deployed.** BL-03 (Blocks/Deadlocks dependency), BL-04 (`Errors`) and "change record / sign-off per the decision paper" are still listed as open. | Retrospective approval needed | Close BL-03 / BL-04; record sign-off |
| A9 | **Target not yet met.** Best projection is ~6 TB/month (range 6–10) against 4.5. Sunday 24 Aug was the only full-day measurement; BL-02 (weekday measure) is still open. | Savings figures below are estimates | Weekday measurement |
| A10 | **Proposed T9 regex would match nothing if the value is `Allowed`.** `"action_s"\s*:\s*"Allow"` requires a closing quote after `Allow`; the repo's own note says the field is commonly `Allowed`. | Fails safe but delivers no saving | Fix after sample (P-09) |

---

## 2. Summary register

### 2.1 In force (deployed)

| Ref | Pipeline | Log source | Filter | Deployed | Est. saving (TB/mo) | Assessed risk |
|---|---|---|---|---|---:|---|
| F-01 | Azure_SQL_Filter | AZURE_SQL | R2 — drop `BATCH STARTED` markers | 18–20 Aug | in F-02 total | Low |
| F-02 | Azure_SQL_Filter | AZURE_SQL | R1 — drop 11 diagnostic/performance categories | 22 Aug | ~5.74 (F-01…F-04 combined, ~92% cut) | Low |
| F-03 | Azure_SQL_Filter | AZURE_SQL | R3 — drop Azure Monitor metrics (`timeGrain":"PT`) | 22 Aug | (included above) | Low |
| F-04 | Azure_SQL_Filter | AZURE_SQL | Redact preset PII patterns + `statement` text | 22 Aug | (included above) | **Medium — see A2** |
| F-05 | AWS_Filter | AWS_CLOUDTRAIL | 3 enumerated `eventName` read-only drop lists | 14–19 Aug | (pre-existing; in F-06 total) | Low–Medium (content not in repo) |
| F-06 | AWS_Filter | AWS_CLOUDTRAIL | Rule A — drop `readOnly:true` | 22 Aug | ~5.20 (F-05…F-07 combined, ~80% cut at first read) | **Medium — see A4** |
| F-07 | AWS_Filter | AWS_CLOUDTRAIL | Rule B — drop AWS-service `invokedBy` | 22 Aug | (included above) | **Medium — see A3** |
| F-08 | AWS_Filter2 | AWS_WAF | Drop monitoring-agent User-Agents on ALB | 17–20 Aug | small (not separately sized) | **Medium — see A6** |
| F-09 | ZSCALER_Filter | ZSCALER_WEBPROXY | Z0 — drop Darktrace sensor traffic | 21 Aug | small | Low |
| F-10 | ZSCALER_Filter | ZSCALER_WEBPROXY | Z1 — drop allowed/no-threat Microsoft estate | 22 Aug | ~0.4 | **Medium — see A5** |
| F-11 | Microsoft_Insights_Components | MICROSOFT_INSIGHTS_COMPONENTS | Source removed entirely | 20–21 Aug | ~0.83 | Low–Medium (rationale to be confirmed) |
| | | | **Deployed total (repo estimate)** | | **~12.2** | |

### 2.2 Proposed / not in force

| Ref | Pipeline / source | Filter | Est. saving (TB/mo) | Status |
|---|---|---|---:|---|
| P-01 | ZSCALER_Filter / WEBPROXY | Category-based allowed/no-threat drop | ~0.7–1.4 (mid ~1.1) | **Status unconfirmed — A1** |
| P-02 (T1) | AWS_Filter2 / AWS_WAF | Drop `action":"ALLOW"` | ~1.49 | Needs 1 sample + sign-off |
| P-03 (T3) | ZPA | Drop allowed + no-threat | ~0.09 | Confirm fields |
| P-04 (T4) | AWS_VPC_FLOW | Drop ACCEPT, keep REJECT | ~0.12 | Needs 1 sample |
| P-05 (T5) | ZSCALER_DNS | Drop trusted-domain resolutions | ~0.09 | Confirm field |
| P-06 (T6) | ZSCALER_FIREWALL | Drop allowed/permitted flows | ~0.08 | Confirm value |
| P-07 (T7) | AZURE_STORAGE_AUDIT | Drop routine read/list ops | ~0.07 | Confirm field |
| P-08 (T8) | AZURE_DOCUMENTDB | Drop routine data-plane reads | ~0.05 | Confirm field |
| P-09 (T9) | AZURE_WAF | Drop ALLOW, keep BLOCK | ~0.02 | Regex defect — A10 |
| P-10 (T10) | GCP_CLOUDAUDIT | Drop read-only / DATA_READ | ~0.01 | Confirm structure |
| P-11 | AZURE_DATAPLANE / NSG_FLOW / FIREWALL / ServiceBus / Barracuda | Drop request/allow/read noise | ~0.10 | Assess per source |
| | | **Planned total** | **~3.4** | |

### 2.3 Superseded / rejected / deferred

| Ref | Item | Disposition |
|---|---|---|
| X-01 | Zscaler Z2 (Google), Z3 (Apple), Z4 (CDN) — domain-based | Superseded by P-01. Never deployed. Reference only in `zscaler_filter.json`. |
| X-02 | Azure SQL D3 — drop routine successful DML | **Rejected.** Conflicts with decision paper §4.1/§4.2/§7.4 (exfiltration / insider threat); cannot be expressed safely as a single regex (no AND guard for success/failure). |
| X-03 | Azure SQL D4 — drop successful logins | **Rejected.** Negligible saving; removes failure→success detection. |
| X-04 | Azure SQL R4 — drop logout/teardown churn | **Deferred.** Not added; `action_name` value unconfirmed. |
| X-05 | Azure SQL `Errors` category | **Deferred** — retained pending decision (BL-04). |

---

## 3. Standing conditions (apply to every filter)

| # | Condition |
|---|---|
| SC-1 | **Subtractive only.** Every filter is `Exclude` / `Match: Body` / `Field: empty` (Filter by Regex), or a redact processor. Nothing is added or transformed except F-04. |
| SC-2 | **Fail-safe.** `errorMode: IGNORE` — a record that cannot be evaluated is kept, not dropped. A wrong regex fails to match (saves nothing); it does not drop unrelated data. |
| SC-3 | **Dropped data is unrecoverable and cannot be retro-hunted** in SecOps. Source-side retention (Azure, AWS, Zscaler console) is the only fallback and must be confirmed per source. |
| SC-4 | **Editing is not deploying.** A change is live only after **Rollout**. |
| SC-5 | **Verify by pipeline JSON export, not `updateTime`.** `updateTime` proves a change landed, not that its content is right (Azure SQL R3 took three attempts; two silent no-ops from stray characters). When pasting a regex, click away / Tab — do not press Enter. |
| SC-6 | **Silent-failure controls** (decision paper §7.6): per-log-type volume floor alert; canary event per retained category; rule-firing baseline before/after. SecOps rules do not error when their source data disappears. |
| SC-7 | **Re-verify after any source format change.** Several Zscaler rules assume field order (`action` → `hostname` → `threatcategory`). A reorder fails safe but silently loses the saving. |
| SC-8 | **Pre-deploy for new filters:** one real sample event; regex tested against keep/drop cases; named approver; rollback export taken. |
| SC-9 | **Policy decisions are not engineering defaults.** Anything that trades detection capability for volume (see §5) requires a recorded, accountable decision. |
| SC-10 | **Review cadence:** each filter re-reviewed at least quarterly and on any change to detection content or log source format. _[confirm cadence]_ |

**Standard rollback (all filters):** open the pipeline in BindPlane → remove or revert the processor → Save → **Rollout** → export JSON to confirm. This stops further drops; **it does not restore events already dropped.** Pre-change states are preserved in git (e.g. `pipelines/azure_sql_filter.json` = original 2-processor Azure SQL state).

---

## 4. Deployed filters — one by one

Risk ratings are my draft assessment for the approver, not an agreed rating.

### 4.1 Azure_SQL_Filter — log type `AZURE_SQL`

Pipeline ID `9c7b26bd-11f3-432f-a7df-a30b56a8955f` · Edit: `…/secops-pipelines/9c7b26bd-11f3-432f-a7df-a30b56a8955f`
Governance basis: Decision Paper *Filtering of AZURE_SQL*, 20/08/2026 (J. de Winnaar) — FILTER HEAVILY, P2. Baseline ~205 GB/day (30-day report); paper cites ≈34.5 GB/day.
Live state: 4 processors, `updateTime 2026-08-22T09:00:02Z` (exclusions verified byte-for-byte at 08:37:50Z; redaction **not** verified). Measured: 205 → 23.0 GB/day on Sun 24 Aug (−89%).

#### F-01 — R2: `BATCH STARTED` markers
| | |
|---|---|
| **Regex** | `"action_name":\s*"BATCH STARTED"` |
| **Rationale** | The paired COMPLETED event carries the signal; STARTED is a marker only. High volume, no added evidence. |
| **Retained** | All other audit events incl. batch/RPC completion, logons, permission changes, failures. |
| **Conditions** | The paired COMPLETED events must continue to arrive (canary). |
| **Residual risk** | Low. If a batch never completes (killed session), the STARTED marker is the only trace — judged negligible. |
| **Verification** | Pipeline JSON export 2026-08-22T08:37:50Z. |

#### F-02 — R1: non-security diagnostic / performance / health categories
| | |
|---|---|
| **Regex** | `"category":\s*"(DatabaseWaitStatistics\|QueryStoreWaitStatistics\|QueryStoreRuntimeStatistics\|ResourceUsageStats\|Timeouts\|AutomaticTuning\|WorkflowRuntime\|Blocks\|Deadlocks\|SQLInsights\|DatabaseInstances)"` |
| **Rationale** | Performance/health telemetry carries no authentication, permission, configuration or data-access evidence. Strict superset of the earlier 6 categories (5 added, 0 removed). `SQLSecurityAuditEvents` is untouched. |
| **Retained** | `SQLSecurityAuditEvents`; any new/unknown category (fails safe); `Errors` (deliberately not dropped). |
| **Conditions** | **BL-03:** Cyber Defence to confirm no approved detection uses `Blocks` / `Deadlocks`. **BL-04:** decision on `Errors`. Both open at deploy time (A8). |
| **Residual risk** | Low. `Timeouts` / `Blocks` / `Deadlocks` can occasionally indicate DoS or abusive query activity; considered operational, not security, telemetry. |
| **Verification** | Export 2026-08-22T08:37:50Z. |

#### F-03 — R3: Azure Monitor platform metrics
| | |
|---|---|
| **Regex** | `"timeGrain":\s*"PT` |
| **Rationale** | Platform metrics records (e.g. PT1M streams) carry no security evidence and are an often-overlooked volume source. |
| **Retained** | Everything without a `timeGrain":"PT…` fingerprint. |
| **Conditions** | Fingerprint is a shape match, not a category match: confirm no audit record legitimately contains that string (e.g. inside a `statement`). Fails safe if absent. |
| **Residual risk** | Low. Whole-body match could in theory hit the same text inside a SQL statement. |
| **Verification** | Landed correctly on third attempt; export 2026-08-22T08:37:50Z. |

#### F-04 — `redact_sensitive_data` (preset patterns + statement text)
| | |
|---|---|
| **Config** | `redactProcessor`, `hashFunction: NONE` (asterisk censor), `redactAllTypes: true`, `allowAllKeys: true`. 14 preset patterns (IBAN, MAC, card, date, email, IPv4, IPv6, phone ×2, US SSN, city/state, street address, ZIP, UUID) plus custom `"statement":"[^"]*"`. |
| **Rationale** | Field pruning, not event dropping, is the preferred way to cut bytes without losing detection (design doc Step 3): the SQL `statement` / `additional_information` text dominates event size. Retains the skeleton of who / what / from where. Also reduces personal data held in SecOps. |
| **Retained (intended)** | Principal, client IP, database, object, action, outcome, timestamp. |
| **Conditions** | **BL-01 (open, blocking):** inspect one live event and confirm (1) only the statement *value* is blanked, key label intact; (2) **client IP, principal/email, object identifiers (UUIDs) and timestamps survive** — presets are applied to the whole body (A2); (3) downstream SecOps parsing still succeeds. If (2) fails, narrow the processor to the custom statement rule only. |
| **Residual risk** | **Medium until BL-01 closed.** Loss of the statement text also removes the ability to detect by query content (e.g. injection strings, `xp_cmdshell`) — accepted trade-off per design doc; Azure-side audit retention (open decision #5) is the fallback. |
| **Verification** | Processor present in export 2026-08-22T09:00:02Z. **Output NOT verified.** |

---

### 4.2 AWS_Filter — CloudTrail

Pipeline ID `c072e6b7-0690-419c-82ca-901b7ab2bc3f` · Feed `2ff7b983-0b01-4303-9848-4ce9b3db2bd3`
Live state: 5 processors (3 enumerated + A + B), `updateTime 2026-08-22T09:59:26Z`, A + B verified byte-for-byte. Measured: 213 → 3.7 GB/day on Sun 24 Aug (−98%).
Governance: CloudTrail = "who looked" vs "who changed something"; attacks are overwhelmingly writes; recon detection is delivered by GuardDuty (ingested).

#### F-05 — Three enumerated `eventName` drop lists
| | |
|---|---|
| **Rule** | Three Filter-by-Regex processors listing ~800 read-only event names. **Contents not in repo (A7).** |
| **Rationale** | Original volume reduction (created 14 Aug, edited 19 Aug). Includes a **prior decision to drop KMS `Encrypt` / `GenerateDataKey`** (noted in commit `30d9685`; approver / paper reference not recorded). Rule 2 was found ~97% redundant with Rule 1. |
| **Conditions** | Export and attach the three regexes. Record approver for the KMS decision. Once Rule A is proven, these are largely redundant and can be simplified (not now). |
| **Residual risk** | Low–Medium: the KMS decision removes visibility of key usage volume (KMS reads/writes are otherwise `readOnly:false` and would have been kept by Rule A). |

#### F-06 — Rule A: drop `readOnly:true`
| | |
|---|---|
| **Regex** | `"readOnly"\s*:\s*true` |
| **Rationale** | Uses AWS's own read/write classification rather than a hand-maintained list. Biggest single win (~5.2 TB/mo across A+B+lists). All `readOnly:false` events (create / delete / modify / permission change) are kept. |
| **Retained** | All writes; events where `readOnly` is absent; `readOnly:"true"` strings are **not** matched (boolean only). |
| **Conditions** | (1) GuardDuty ingestion confirmed active (A4). (2) Cyber Defence to list any SecOps rule or hunt that relies on read events (secret / parameter retrieval, STS, enumeration) before sign-off. (3) Confirm Rule A is *actually firing* on live events — evidenced indirectly by the −98% drop, but no live event was inspected. |
| **Residual risk** | **Medium.** Credential-access and reconnaissance reads are not in SecOps. Compensating control: GuardDuty findings; AWS-side CloudTrail retention. |
| **Verification** | Export 2026-08-22T09:59:26Z. Tested against 10 cases incl. writes, KMS Encrypt, DeleteTrail, real-user calls, decoy "true" elsewhere — all kept correctly. |

#### F-07 — Rule B: drop AWS-service-invoked events
| | |
|---|---|
| **Regex** | `"invokedBy"\s*:\s*"[a-z0-9.\-]+\.amazonaws\.com"` |
| **Rationale** | AWS services calling other services (automation) are machines, not people or attackers. Small top-up over Rule A. |
| **Retained** | Events with no AWS-service `invokedBy` — i.e. direct user / role / external callers. |
| **Conditions** | **Approver to accept A3:** Rule B drops write events too (e.g. CloudFormation / Auto Scaling acting on a principal's behalf). The principal's original API call is still logged. Field-order independent. |
| **Residual risk** | **Medium–Low.** Abuse of service-linked or chained actions would show only the originating call. |
| **Verification** | Export 2026-08-22T09:59:26Z. |

---

### 4.3 AWS_Filter2 — AWS WAF

Pipeline ID `6f17d9b9-8874-4c5b-9a54-eca796841abc` · Feed `4cc610fa-2e49-467b-a573-00a1cdcd6480` · Last update `2026-08-20T15:38:17Z`.
Baseline ~65 GB/day (#4 source). Sun 24 Aug: 27.1 GB/day (−58%) — **this reduction is not from an ALLOW filter**; it is lighter Sunday traffic plus this narrow rule.

#### F-08 — Monitoring-agent User-Agents on ALB
| | |
|---|---|
| **Rule** | Drop where `httpSourceName":"ALB"` and a `User-Agent` header value begins `ELB-HealthChecker/x`, `Blackbox Exporter/x`, `Grafana/x` or `Java-EurekaClient[-Replication]/vx`. |
| **Rationale** | Health-check and monitoring probes generate large, repetitive, zero-security-value requests. |
| **Retained** | All other traffic, including all non-ALB sources. |
| **Conditions** | **A6:** rule is not action-aware and has no source-IP guard. Approver to accept, or add a guard (e.g. restrict to ALLOW, or internal source ranges). |
| **Residual risk** | **Medium–Low.** Trivially spoofable by an attacker (tested); also drops BLOCKED probes using these UAs. |
| **Verification** | `aws_waf_filter_LIVE.json` (20 Aug 15:38). |

---

### 4.4 ZSCALER_Filter — ZSCALER_WEBPROXY

Pipeline ID `7d023b21-3b13-4580-9174-a86b14dace06` · Feed `02d280ff-d19e-494f-8319-81a8545fdf42` · Created 21 Aug 14:33.
Baseline ~95 GB/day. Sun 24 Aug: 29.0 GB/day (−69%, includes lighter Sunday traffic).
**Filters are per-feed (BL-08):** other Zscaler feeds (ZPA, DNS, Firewall) are not covered by this pipeline.
**Owner decision 22 Aug 2026:** blocked traffic is reviewed in the Zscaler console and need not be preserved in SecOps (a "drop blocked" rule is not built — `action` value for blocked unconfirmed).

#### F-09 — Z0: Darktrace sensor traffic
| | |
|---|---|
| **Regex** | `(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.darktracesensor\.com".*?"threatcategory"\s*:\s*"None")` |
| **Rationale** | Our own security tooling phoning home; allowed, no threat, no investigative value. Proven pattern that Z1 clones. |
| **Retained** | Blocked, threat-flagged, or any non-Darktrace host. |
| **Conditions** | Field order `action → hostname → threatcategory` must hold (SC-7). |
| **Residual risk** | Low. |

#### F-10 — Z1: allowed / no-threat Microsoft estate
| | |
|---|---|
| **Regex** | `(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(microsoft\|office\|office365\|windows\|windowsupdate\|azure\|azureedge\|msftconnecttest\|msedge\|live\|microsoftonline)\.(com\|net)".*?"threatcategory"\s*:\s*"None")` |
| **Rationale** | Updates, Office 365, Windows telemetry and Azure endpoints are the bulk of web-proxy noise. Triple guard: Allowed **and** trusted-suffix **and** `threatcategory=None`. Lookalikes such as `microsoft.com.attacker.ru` are kept (domain must be at the end of the hostname — tested). |
| **Retained** | Blocked; any threat category; unknown / lookalike domains. |
| **Conditions** | **A5:** approver to accept that `*.windows.net` / `*.azureedge.net` / `*.live.com` host third-party content (tested: `evil-acct.blob.core.windows.net` dropped), or narrow the list. Field-order dependence (SC-7). |
| **Residual risk** | **Medium.** Malware staging or C2 on Azure storage / CDN rated `None` by Zscaler is invisible in SecOps. Compensating control: Zscaler console retention; endpoint (EDR) telemetry. |
| **Verification** | Export 2026-08-22T09:38:20Z, exact match. |

---

### 4.5 Microsoft_Insights_Components

#### F-11 — Source removed
| | |
|---|---|
| **Pipeline** | `54d1435e-1c44-44f3-a581-ee7ff2a83448`, log type `MICROSOFT_INSIGHTS_COMPONENTS`. Pipeline created 20 Aug 12:41, updated 12:46; schedule records removal on 21 Aug (date discrepancy — confirm). |
| **Rationale (recorded)** | Volume: ~27 GB/day, ~0.83 TB/month, removed entirely; 0 GB/day confirmed. **No security rationale is recorded in the repo** — owner to state it (application performance telemetry, not audit evidence) and confirm that no detection uses it. |
| **Conditions** | Attach the pipeline definition (A7). Zero volume is a *deliberate* state — exclude this log type from the SC-6 volume-floor alert, and record that exception. |
| **Residual risk** | Low–Medium pending owner confirmation. |

---

## 5. Proposed filters — one by one (NOT in force)

None of these may be deployed until the stated conditions are met and the change is approved. Paste-ready regexes are in `pipelines/REMAINING_TARGETS_SPEC.md`.

### P-01 — Zscaler category-based drop (status unconfirmed, A1)
| | |
|---|---|
| **Rule** | Drop where `action=Allowed`, `category_details` in {Business and Economy; Other Business and Economy; Exception Dynatrace; EMIS SSL Bypass; EMIS – AWS Cloud Connector Whitelist; EMIS GitHub Runners Whitelist; AAA_SSL_Microsoft_Windows_Endpoint_Optimization; AAA_SSL_Apple_Domains; Zscaler Proxy IPs}, and `threatcategory=None`. |
| **Rationale** | Category-based rather than hostname-based: broader, self-maintaining, uses the organisation's own EMIS whitelists, and covers the Microsoft / Apple domains the superseded Z2–Z4 targeted. Est. ~0.7–1.4 TB/mo, dominated by Business and Economy. |
| **Conditions** | Current state confirmed by export. Security approver to accept that **Business and Economy is a broad, third-party-controlled category** — a compromised or malicious site mis-categorised there with `threatcategory=None` becomes invisible. Confirm the EMIS whitelist categories are curated by a named owner. Field-order dependence. |
| **Residual risk** | **Medium.** Loss of hunt capability on allowed traffic (same trade-off as Z1, wider). |

### P-02 (T1) — AWS WAF: drop `"action":"ALLOW"`
| | |
|---|---|
| **Regex** | `"action"\s*:\s*"ALLOW"` |
| **Rationale** | Biggest remaining lever (~1.49 TB/mo, ~75% of WAF volume). Keeps every `BLOCK` and `COUNT` — the security signal. |
| **Conditions (mandatory)** | (1) **One real WAF event** to confirm the `action` field and value. (2) **Recorded sign-off** — WAF fronts public-facing applications. (3) Security approver accepts that allowed attacks that evade WAF rules are not visible in SecOps (compensating: app-layer logs, CloudTrail). (4) Consider scoping out sensitive apps, or retaining a sample. |
| **Residual risk** | **Medium–High.** Also removes the ability to retro-hunt an IOC (IP, UA, path) against allowed requests. |

### P-03 (T3) — ZPA
Regex `(?s:"action"\s*:\s*"Allowed".*?"threatcategory"\s*:\s*"None")`. **Rationale:** same proven pattern as webproxy on the ZPA feed (~0.09 TB/mo). **Conditions:** confirm ZPA uses the same field names. **Note:** as written this drops *all* allowed + no-threat access to *any* app — broader than the "trusted internal apps" description; add a hostname clause to keep sensitive applications. **Residual risk:** Medium (private-application access is high-value for lateral-movement hunting).

### P-04 (T4) — AWS VPC Flow
Regex (JSON) `"action"\s*:\s*"ACCEPT"` or (text) `\sACCEPT\s+OK\s*$`. **Rationale:** flow logs are mostly ACCEPT; keep every REJECT (~0.12 TB/mo). **Conditions:** one sample to choose the right regex. **Residual risk:** Medium — accepted flows are the evidence for exfiltration and lateral movement; consider restricting the drop to known-good ranges/ports.

### P-05 (T5) — Zscaler DNS
Regex drops queries to `microsoft|windows|google|googleapis|apple|icloud|akamai|cloudflare` `.com|.net`. **Rationale:** trusted-domain resolutions (~0.09 TB/mo). **Conditions:** confirm the DNS domain field name; the draft key pattern is a guess. **Residual risk:** Low–Medium (no action/threat guard in the draft; consider adding).

### P-06 (T6) — Zscaler Firewall
Regex `"action"\s*:\s*"(Allow|Allowed|Permitted)"`. **Rationale:** routine permitted flows (~0.08 TB/mo). **Conditions:** confirm allowed-value string. **Note:** drops *all* allowed flows, not just routine ones. **Residual risk:** Medium.

### P-07 (T7) — Azure Storage Audit
Regex on `OperationName` in {GetBlob, GetBlobProperties, GetBlobServiceProperties, ListBlobs, GetContainerProperties, GetContainerACL, HeadBlob, GetBlobMetadata, ListContainers}. **Rationale:** routine reads (~0.07 TB/mo); writes / deletes / permission changes kept. **Conditions:** confirm field name and casing. **Residual risk:** Medium — `GetBlob` volume is the primary mass-download / exfiltration signal; consider retaining it and dropping only list/property operations.

### P-08 (T8) — Azure DocumentDB (Cosmos)
Regex `"OperationName"\s*:\s*"(Query|ReadFeed|Get|Read)"`. **Rationale:** routine data-plane reads (~0.05 TB/mo); control-plane and auth kept. **Conditions:** confirm field and values. **Residual risk:** Medium (same exfiltration trade-off as P-07).

### P-09 (T9) — Azure WAF
Regex `"action_s"\s*:\s*"Allow"`. **Rationale:** same as P-02 (~0.02 TB/mo). **Conditions:** **fix regex first (A10)** — likely needs `Allowed`; confirm from a sample; keep Blocked / Matched. **Residual risk:** Medium (as P-02).

### P-10 (T10) — GCP CloudAudit
Regex on `AuditLog` with `methodName` ending `.get|.list|.aggregatedList`. **Rationale:** DATA_READ noise; ADMIN_ACTIVITY kept (~0.01 TB/mo). **Conditions:** confirm structure; prefer filtering by log type. **Residual risk:** Low–Medium.

### P-11 — Tail (AZURE_DATAPLANE, NSG_FLOW, FIREWALL, ServiceBus, Barracuda)
~0.10 TB/mo combined. **Conditions:** assess each source individually before any rule is drafted. No regex exists yet.

---

## 6. Expected outcome and remaining gap

| Stage | TB/month |
|---|---:|
| Baseline (pre-change) | ~19.9–21 |
| After deployed filters (est.) | ~7.8 (−63% like-for-like Saturday) |
| Sun 24 Aug day, extrapolated weekday/weekend-corrected | **~6 (range 6–10)** |
| After P-02 (WAF ALLOW) | ~5.5 |
| After full planned schedule | ~4.7 |
| **Target** | **4.5** |

Safe, zero-detection-cost filtering reaches roughly a 71% cut; the target needs ~78%. The last stretch is a **policy decision**, not engineering. Options that were consciously declined and would need explicit sign-off: successful routine Azure SQL DML (X-02), a blanket Zscaler "drop allowed" posture, further CloudTrail write reductions. These must not be implemented silently to hit the number (SC-9).

---

## 7. Open items

| ID | Item | Owner |
|---|---|---|
| BL-01 | Verify Azure SQL redaction output (statement value only; **plus client IP / identity retained** — A2) | _[ ]_ |
| BL-02 | Measure on first full weekday | _[ ]_ |
| BL-03 | Confirm no live detection depends on `Blocks` / `Deadlocks` | Cyber Defence |
| BL-04 | Decide on `Errors` category | Cyber Defence |
| BL-06 | Rotate BindPlane API keys shared during setup | _[ ]_ |
| BL-08 | Confirm single vs multiple Zscaler feeds | _[ ]_ |
| BL-10 | AWS WAF ALLOW drop — sample + sign-off | _[ ]_ |
| NEW-1 | Reconcile register against live instance (`export-filters.sh`) | _[ ]_ |
| NEW-2 | Attach missing exports (A7) | _[ ]_ |
| NEW-3 | Decide A3, A5, A6 (accept / narrow) | Security approver |
| NEW-4 | Azure SQL open decisions #3 (backup vs restore), #5 (Azure-side audit retention retrievable in incident timeframes), #6 (patient / sensitive data) | Cyber Defence / Cloud Eng / DPO |

---

## 8. Approval

| Role | Name | Decision (Approve / Approve with conditions / Reject) | Date | Signature |
|---|---|---|---|---|
| Change owner | | | | |
| Security / Cyber Defence | | | | |
| Cloud / platform engineering | | | | |
| Information governance / DPO | | | | |

**Conditions attached to approval:** _[to be completed]_

---

## Appendix — evidence files in this repository

| Evidence | File |
|---|---|
| Schedule, results, open items | `inventory/FILTER_SCHEDULE.md` |
| Roadmap to target | `PATH_TO_4.5TB.md` |
| Azure SQL design, security assessment | `pipelines/AZURE_SQL_FILTER_DESIGN.md`, `AZURE_SQL_FILTER_RULES.md`, `DEPLOY_AZURE_SQL.md` |
| Azure SQL original (rollback) / live | `pipelines/azure_sql_filter.json` / `azure_sql_filter_LIVE_20260822.json` |
| CloudTrail Rule A/B | `pipelines/aws_cloudtrail_filter.json`, `DEPLOY_AWS_CLOUDTRAIL.md` |
| AWS WAF live | `pipelines/aws_waf_filter_LIVE.json` |
| Zscaler live / proposed | `pipelines/zscaler_filter.json`, `zscaler_filter_category_PROPOSED.json`, `DEPLOY_ZSCALER.md` |
| Remaining targets | `pipelines/REMAINING_TARGETS_SPEC.md` |
| Pipeline summaries snapshot | `inventory/snapshots/20260822T072129Z/` |
