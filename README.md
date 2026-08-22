# bindplane-secops-config

GitOps / configuration repository for **Google SecOps (Chronicle)** telemetry filtering in [BindPlane](https://docs.bindplane.com/).

This repo holds **data, not code** — versioned BindPlane resource definitions (processors, destinations, configurations) that are applied to a BindPlane instance via `bindplane apply` (or the `/v1/apply` API, e.g. through the `mcp-bindplane` MCP server's `resources` tool).

> The reusable MCP server that *drives* these applies lives in a separate repo (`mcp-bindplane`). Keep tenant-specific config here; keep generic tooling there.

## Why this repo exists

We need to control what telemetry is sent into Google SecOps — dropping noise, keeping the relevant log types, standardising log type / namespace / ingestion labels, and batching to stay under the SecOps API's 4 MB request limit. In BindPlane that is expressed as **processors on the pipeline feeding the SecOps destination**, not as bespoke code.

## Layout

```
bindplane-secops-config/
├── README.md
├── inventory/
│   ├── FILTER_SCHEDULE.md        # THE SCHEDULE: human-readable register of every filter (existing + planned)
│   ├── export-filters.sh         # Pulls current processors/configs from a live BindPlane instance
│   └── snapshots/                # Timestamped raw exports (git-tracked evidence of state over time)
├── processors/
│   ├── _templates/               # Copy-me starting points
│   │   ├── filter-processor.yaml
│   │   ├── batch-processor.yaml
│   │   └── secops-standardization-processor.yaml
│   └── ...                       # One file per real processor (named to match the schedule)
├── destinations/
│   ├── _templates/
│   │   └── google-secops-destination.yaml
│   └── ...
├── configurations/               # Full pipeline configs wiring source → processors → SecOps destination
│   └── ...
└── scripts/
    └── apply.sh                  # Apply a spec (or a whole dir) to the target instance
```

## Workflow

1. **Inventory first.** Run `inventory/export-filters.sh` against the live instance (read-only) to capture current state into `inventory/snapshots/`, then reconcile `inventory/FILTER_SCHEDULE.md` so the schedule reflects reality.
2. **Author new filters.** Copy a template from `processors/_templates/`, edit, add a row to the schedule (status `planned`).
3. **Review** the spec (PR).
4. **Apply.** `scripts/apply.sh processors/<file>.yaml` (dry-run first), then mark the schedule row `deployed`.

## Prerequisites

- The `bindplane` CLI **or** `curl` + a BindPlane API key, **or** the `mcp-bindplane` MCP server configured against the target instance.
- Environment variables (never commit real values — use a local `.env` that is git-ignored):
  - `BINDPLANE_URL` — e.g. `https://app.bindplane.com`
  - `BINDPLANE_API_KEY` — read scope is enough for inventory; write scope needed to apply

## Conventions

- **Naming:** `secops-<pipeline>-<purpose>` (e.g. `secops-windows-filter-noise`, `secops-firewall-batch`).
- **`apiVersion`:** `bindplane.observiq.com/v1` unless a v2-only feature is required.
- **One resource per file**, filename == `metadata.name`.
- Every filter that exists on the instance MUST have a row in `FILTER_SCHEDULE.md`. The schedule is the source of truth for review; the instance is the source of truth for runtime.
