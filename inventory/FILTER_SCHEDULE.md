# Google SecOps — Filter Schedule

The **single register** of every filter/processor in scope for Google SecOps ingestion: what exists today, what is planned, and the current deployment state of each.

- **Existing filters** are reconciled against `snapshots/` exports (see `export-filters.sh`).
- **New filters** are added here as `planned` before their spec is written, then moved to `built` → `deployed`.

> This document is the source of truth for **review**. The live BindPlane instance is the source of truth for **runtime**. Keep them reconciled after every apply.

**Last reconciled:** 2026-08-22 (snapshot `20260822T070416Z`), instance `https://app.bindplane.com`.

---

**Scope:** This schedule covers **SecOps pipelines only**. Non-SecOps configs/destinations (e.g. `test` → `s`/`dev_null`) are intentionally excluded.

## Environment summary (SecOps pipelines)

| Item | Value |
|---|---|
| SecOps customer ID | `c98f7d82-a2a4-45a1-a96a-a4dee6cf39fd` |
| GCP project number | `721279881207` |
| Region | `europe-west2` |
| Protocol / API | `https` (Chronicle), api_version `v1alpha` |
| **Live SecOps pipeline** | **`OptumUKWinEvtLog` → `ptmkc`** (namespace `OptumUK`) — the only SecOps config with a source feeding a Chronicle destination |
| SecOps destination `ptmkc` | in use by `OptumUKWinEvtLog`; namespace `OptumUK` |
| SecOps destination `test` | defined but **not attached to any live config** — parked, not a real pipeline |
| Source in the live pipeline | `windowsevents_v3` (+ `bindplane-agent`) |

> `credentials` / `credentials_file` on the SecOps destination are secrets and are intentionally NOT recorded here.

---

## Legend

| Field | Meaning |
|---|---|
| **ID** | Stable short id / resource or sub-processor name. |
| **Form** | `bundle` (Blueprint/processor_bundle library resource) · `inline` (processor on a destination inside a config) · `standalone` (top-level Processor resource). |
| **Type** | BindPlane processor type. |
| **Attached to** | Which config/destination actually runs it (a bundle in the library is not "live" until attached). |
| **Purpose** | One line. |
| **Status** | `existing-live` (attached & running) · `existing-library` (defined but not attached) · `planned` · `built` · `deployed` · `deprecated`. |

---

## Existing filters (from instance)

### A. Reusable Blueprint bundles (library — reduce SecOps ingest volume)

> These are defined as `processor_bundle` / `Blueprint` resources. **Verify whether each is actually attached to a live configuration** — as of this snapshot neither bundle appears attached to `OptumUKWinEvtLog` (the only live SecOps config), so they are library-only until wired in.

| ID | Form | Type | Sub-steps | Purpose | Status |
|----|------|------|-----------|---------|--------|
| `crowdstrike-falcon-google-secops-volume-reduction` | bundle | processor_bundle | parse_json → 3× filter-by-condition → delete_fields → dedup → delete_empty → SecOps standardization | Cut CrowdStrike Falcon FDR volume into SecOps | existing-library |
| `reduce-cloudtrail-logs` | bundle | processor_bundle | parse_json → filter-by-condition → delete_empty | Drop read-only AWS CloudTrail noise | existing-library |

**Bundle sub-filters (the actual drop rules):**

| Bundle | Sub-filter | Drops | Condition (summary) |
|--------|-----------|-------|---------------------|
| crowdstrike…volume-reduction | Drop Low-Signal Event Types | Housekeeping/redundant events | `event_simpleName` ∈ {EndOfProcess(+V15/MacV15), SyntheticProcessRollup2, ConfigStateUpdate(+V3), ConfigStateHash, ChannelActive(+V1), CurrentSystemTags(+V1), LFODownloadConfirmation(+V1), SpotlightEntityBatchHeader(+V3), ProcessRollup2Stats} |
| crowdstrike…volume-reduction | Drop Benign DNS Requests | Known-good vendor DNS lookups | `event_simpleName` ∈ {DnsRequest, DnsRequestV4} AND `DomainName` matches allowlist (microsoft/windows/apple/google/akamai/cloudflare/crowdstrike etc.) |
| crowdstrike…volume-reduction | Drop Routine Internal Network Events | RFC1918 / loopback connections | `event_simpleName` ∈ {NetworkConnectIP4(+V12), NetworkReceiveAcceptIP4V12} AND `RemoteAddressIP4` matches `^(127.|10.|172.16–31.|192.168.)` |
| reduce-cloudtrail-logs | Filter Read Only Data | Read-only AWS API calls | `eventName` contains {AuditUser, List, Get, Describe} OR `readOnly == "true"` |

### B. Inline processors on live SecOps destination

| ID | Form | Type | Attached to | Purpose | Status |
|----|------|------|-------------|---------|--------|
| `OptumUKWinEvtLog / ptmkc / copy_field` | inline | copy_field | config `OptumUKWinEvtLog` → dest `ptmkc` | Copy Resource `host.name` → `chronicle_ingestion_labels["ingestion_source"]` | existing-live |
| `OptumUKWinEvtLog / ptmkc / batch` | inline | batch | config `OptumUKWinEvtLog` → dest `ptmkc` | Batch to SecOps (size 1024 / max 2048 / timeout 10s) | existing-live |

> ⚠ Note: no actual **drop/keep filter** is currently live on the `OptumUKWinEvtLog` → `ptmkc` (Windows Events → SecOps) pipeline — only label-copy + batch. Windows Event filtering is a candidate for the "new filters" work below.

---

## Planned / new filters

| ID | Form | Type | Attached to | Purpose | Rule summary | Status | Owner |
|----|------|------|-------------|---------|--------------|--------|-------|
| _(add rows as we design them)_ | | | | | | | |

Candidate starting points (to confirm with you):
1. **Wire the existing bundles in** — attach `crowdstrike-…-volume-reduction` / `reduce-cloudtrail-logs` to their live configs so the library filtering actually runs (they appear unattached today).
2. **Windows Event volume reduction** for `OptumUKWinEvtLog → ptmkc` — e.g. drop high-noise Event IDs (verbose logon/logoff 4634/4658, etc.) per your detection needs.
3. **Batch tuning** — current inline batch is 1024/2048/10s; SecOps best practice suggests 1365/2048/2s per log type.

---

## Change log

| Date | Change | By |
|------|--------|-----|
| 2026-08-22 | Initial reconciliation against snapshot `20260822T070416Z`. Recorded 2 Blueprint bundles (library), 2 inline processors on `ptmkc`, 2 SecOps destinations (`ptmkc`, `test`). | export-filters.sh |
