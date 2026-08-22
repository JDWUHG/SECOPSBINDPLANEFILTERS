#!/usr/bin/env bash
#
# apply.sh — Apply one or more BindPlane resource specs to the target instance.
#
# Requires: bindplane CLI OR curl+jq. Reads config from env or ../inventory/.env.
#   BINDPLANE_URL, BINDPLANE_API_KEY (write scope needed)
#
# Usage:
#   ./apply.sh --dry-run processors/secops-windows-filter-noise.yaml
#   ./apply.sh processors/secops-windows-filter-noise.yaml
#   ./apply.sh processors/            # apply every .yaml in a directory
#
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; shift; fi
[ $# -ge 1 ] || { echo "usage: $0 [--dry-run] <file-or-dir> [more...]" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/inventory/.env" ] && { set -a; . "$ROOT/inventory/.env"; set +a; }
: "${BINDPLANE_URL:?Set BINDPLANE_URL}"
: "${BINDPLANE_API_KEY:?Set BINDPLANE_API_KEY (write scope)}"

# Collect target files
FILES=()
for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(find "$arg" -type f \( -name '*.yaml' -o -name '*.yml' \) ! -path '*/_templates/*')
  else
    FILES+=("$arg")
  fi
done

echo "About to apply ${#FILES[@]} spec(s) to ${BINDPLANE_URL} (dry-run=$DRY_RUN):"
printf '  - %s\n' "${FILES[@]}"

if command -v bindplane >/dev/null; then
  for f in "${FILES[@]}"; do
    if [ "$DRY_RUN" = "1" ]; then
      echo "== [dry-run] would run: bindplane apply -f $f =="
    else
      bindplane apply -f "$f"
    fi
  done
else
  echo "(bindplane CLI not found — falling back to /v1/apply via curl)"
  command -v jq >/dev/null || { echo "jq required for curl fallback" >&2; exit 1; }
  # NOTE: this fallback expects YAML converted to JSON. Prefer the bindplane CLI,
  # or apply via the mcp-bindplane 'resources' tool (action: apply) which accepts JSON specs.
  echo "curl fallback requires JSON specs. Use the bindplane CLI or the mcp-bindplane resources tool." >&2
  exit 2
fi

echo "Done. Remember to update inventory/FILTER_SCHEDULE.md status -> deployed."
