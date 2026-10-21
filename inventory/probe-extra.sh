#!/usr/bin/env bash
# probe-extra.sh — discover how to read SecOps pipeline definitions when GraphQL
# introspection is disabled, by using validation-error suggestions.
# Prints only GraphQL error MESSAGES (field/type names) and pipeline metadata
# (id, name, log types, timestamps) — safe for a public log.
set -uo pipefail
: "${BINDPLANE_URL:?}"; : "${BINDPLANE_API_KEY:?}"
OUT="${1:-./probe-out}"; mkdir -p "$OUT"
BASE="${BINDPLANE_URL%/}"
H=(-H "X-Bindplane-Api-Key: ${BINDPLANE_API_KEY}")
[ -n "${BINDPLANE_ACCOUNT_ID:-}" ] && H+=(-H "X-Bindplane-Account-ID: ${BINDPLANE_ACCOUNT_ID}")

q() { # q <graphql query string>  -> prints compact error messages only
  local body; body=$(jq -n --arg q "$1" '{query:$q}')
  curl -sS -m 40 "${H[@]}" -H 'Content-Type: application/json' -X POST -d "$body" "${BASE}/v1/graphql" 2>/dev/null
}

echo "== Pipeline metadata (id | name | logTypes | created | updated) =="
q '{ secOpsPipelineSummaries { id displayName description logTypes createTime updateTime } }' > "$OUT/summaries_full.json"
jq -r '.data.secOpsPipelineSummaries[]? | [.id,.displayName,(.logTypes|join(",")),.createTime,.updateTime] | @tsv' "$OUT/summaries_full.json"

echo; echo "== Query-field candidates (message only) =="
for n in secOpsPipeline secOpsPipelineByID secOpsPipelineById secOpsPipelineDetails secOpsPipelineDetail \
         secOpsPipelineConfiguration secOpsPipelineProcessors secOpsPipelineSummary secOpsPipelineVersion \
         logProcessingPipeline logProcessingPipelines secOpsFeeds secOpsLogTypes secOpsDestinations \
         secOpsProcessors secOpsFilters pipeline pipelines; do
  m=$(q "{ $n }" | jq -r '.errors[0].message // "OK(no error)"' 2>/dev/null)
  printf '%-30s %s\n' "$n" "$m"
done

echo; echo "== Fields on the summary type (message only) =="
for f in processors filters rules definition config configuration streams resource name feeds logTypes \
         secOpsPipelineProcessors processorsJSON spec body yaml json; do
  m=$(q "{ secOpsPipelineSummaries { $f } }" | jq -r '.errors[0].message // "EXISTS"' 2>/dev/null)
  printf '%-30s %s\n' "$f" "$m"
done

echo; echo "== secOpsFeeds probe (to see feed shape) =="
for f in id displayName name logType logTypes pipeline pipelineId pipelines processors; do
  m=$(q "{ secOpsFeeds { $f } }" | jq -r '.errors[0].message // "EXISTS"' 2>/dev/null)
  printf '%-30s %s\n' "$f" "$m"
done
echo "== Done =="
