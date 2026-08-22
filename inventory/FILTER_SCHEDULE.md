# Google SecOps — Filter Schedule

The **single register** of every filter/processor in scope for Google SecOps ingestion: what exists today, what is planned, and the current deployment state of each.

- **Existing filters** are populated by reconciling against `snapshots/` exports (see `export-filters.sh`).
- **New filters** are added here as `planned` before their spec is written, then moved to `built` → `deployed`.

> This document is the source of truth for **review**. The live BindPlane instance is the source of truth for **runtime**. Keep them reconciled after every apply.

---

## Legend

| Field | Meaning |
|---|---|
| **ID** | Stable short id, matches the spec filename in `../processors/`. |
| **Type** | `filter` (drop/keep), `batch`, `standardization`, `transform`, `dedup`, `sample`. |
| **Pipeline / Config** | The BindPlane configuration this processor belongs to. |
| **Log type(s)** | SecOps log type(s) affected (e.g. `WINDOWS_DHCP`, `NIX_SYSTEM`). |
| **Purpose** | One line: what it keeps/drops/standardises. |
| **Rule summary** | Human summary of the OTTL / condition (full logic lives in the spec). |
| **Status** | `existing` · `planned` · `built` · `deployed` · `deprecated`. |
| **Owner** | Who owns the rule. |
| **Spec** | Relative path to the resource spec file. |
| **Last verified** | Date the row was last reconciled against a snapshot. |

---

## Existing filters (from instance)

> Populated during the inventory step. Until the first export is run against the live instance, this table is a placeholder.

| ID | Type | Pipeline / Config | Log type(s) | Purpose | Rule summary | Status | Owner | Spec | Last verified |
|----|------|-------------------|-------------|---------|--------------|--------|-------|------|---------------|
| _(none captured yet — run `export-filters.sh`)_ | | | | | | | | | |

---

## Planned / new filters

| ID | Type | Pipeline / Config | Log type(s) | Purpose | Rule summary | Status | Owner | Spec | Last verified |
|----|------|-------------------|-------------|---------|--------------|--------|-------|------|---------------|
| _(add rows as we design them)_ | | | | | | | | | |

---

## Change log

| Date | Change | By |
|------|--------|-----|
| _init_ | Schedule created (empty — awaiting first inventory export). | — |
