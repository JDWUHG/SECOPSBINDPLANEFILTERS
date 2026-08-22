#!/usr/bin/env bash
#
# export-filters.sh — Read-only inventory of BindPlane processors & SecOps pipelines.
#
# Captures the current state of the target BindPlane instance into a timestamped
# snapshot, so FILTER_SCHEDULE.md can be reconciled against reality.
#
# Requires: curl, jq. Reads config from environment (or a local ./.env — git-ignored).
#   BINDPLANE_URL      e.g. https://app.bindplane.com
#   BINDPLANE_API_KEY  read scope is sufficient
#
# Usage:
#   ./export-filters.sh                 # writes snapshots/<timestamp>/
#   BINDPLANE_URL=... BINDPLANE_API_KEY=... ./export-filters.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/.env" ] && { set -a; . "$HERE/.env"; set +a; }

: "${BINDPLANE_URL:?Set BINDPLANE_URL (e.g. https://app.bindplane.com)}"
: "${BINDPLANE_API_KEY:?Set BINDPLANE_API_KEY (read scope is enough)}"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HERE/snapshots/$TS"
mkdir -p "$OUT"

AUTH=(-H "X-Bindplane-Api-Key: ${BINDPLANE_API_KEY}")
BASE="${BINDPLANE_URL%/}"

fetch() {
  # fetch <path> <outfile>
  local path="$1" file="$2"
  echo "  GET $path"
  curl -fsS "${AUTH[@]}" "${BASE}${path}" -o "$OUT/$file" \
    || { echo "  ! failed: $path" >&2; echo '{}' > "$OUT/$file"; }
}

echo "Exporting BindPlane state from $BASE -> $OUT"
fetch "/v1/processors"       "processors.json"
fetch "/v1/configurations"   "configurations.json"
fetch "/v1/destinations"     "destinations.json"
fetch "/v1/sources"          "sources.json"

echo
echo "=== SecOps destinations (candidates) ==="
jq -r '
  (.destinations // .items // [])[]
  | select((.spec.type // "" | ascii_downcase) | test("secops|chronicle"))
  | "  - " + (.metadata.name // "?") + "  (type=" + (.spec.type // "?") + ")"
' "$OUT/destinations.json" 2>/dev/null || echo "  (none / unable to parse)"

echo
echo "=== Standalone processors & Blueprint bundles ==="
# BindPlane stores reusable processing as top-level Processor resources OR as
# Blueprint/processor_bundle resources that contain sub-processors. Report both,
# and list the filter/dedup sub-processors inside bundles (the real drop rules).
jq -r '
  (.processors // .items // [])[]
  | .metadata.name as $name
  | (.spec.type // "?") as $t
  | "  - " + $name + "  (type=" + $t + ")"
    + ( if (.spec.processors // []) | length > 0
        then "\n" + ( [ (.spec.processors[]
              | "      · " + (.type // "?") + "  — " + (.displayName // "")) ] | join("\n") )
        else "" end )
' "$OUT/processors.json" 2>/dev/null || echo "  (none / unable to parse)"

echo
echo "=== Inline processors attached to SecOps destinations inside configurations ==="
# Filtering is frequently defined inline on the destination within a config,
# not as a standalone resource. Surface those so the schedule is complete.
jq -r '
  (.configurations // .items // [])[]
  | .metadata.name as $cfg
  | ( (.spec.destinations // [])[]
      | select((.name // "" ) | test("secops|chronicle|ptmkc|test"; "i"))
      | .name as $dest
      | ( (.processors // [])[]?
          | "  - [config " + $cfg + " → dest " + ($dest // "?") + "] " + (.type // "?") ) )
' "$OUT/configurations.json" 2>/dev/null || echo "  (none / unable to parse)"

echo
echo "Snapshot written to: $OUT"
echo "Next: reconcile inventory/FILTER_SCHEDULE.md against these files,"
echo "      committing the snapshot as evidence of the state at $TS."
