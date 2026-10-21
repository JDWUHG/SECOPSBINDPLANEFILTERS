#!/usr/bin/env bash
# probe-extra.sh — round 2: broader validation-error discovery (messages only; public-log safe)
set -uo pipefail
: "${BINDPLANE_URL:?}"; : "${BINDPLANE_API_KEY:?}"
OUT="${1:-./probe-out}"; mkdir -p "$OUT"
BASE="${BINDPLANE_URL%/}"
H=(-H "X-Bindplane-Api-Key: ${BINDPLANE_API_KEY}")
[ -n "${BINDPLANE_ACCOUNT_ID:-}" ] && H+=(-H "X-Bindplane-Account-ID: ${BINDPLANE_ACCOUNT_ID}")
q() { local body; body=$(jq -n --arg q "$1" '{query:$q}')
  curl -sS -m 40 "${H[@]}" -H 'Content-Type: application/json' -X POST -d "$body" "${BASE}/v1/graphql" 2>/dev/null; }

echo "== R2: Query-type names (message only; shows 'did you mean') =="
for n in showSecOpsPipelinesPage secOpsPipelineJSON secOpsPipelineResource secOpsPipelineExport secOpsPipelineYAML \
         secOpsPipelineStatus secOpsPipelineRollout secOpsPipelineProcessor secOpsPipelineProcessorList \
         secOpsPipelineDefinition secOpsPipelineDraft secOpsPipelineRaw getSecOpsPipeline secOpsPipelinesByFeed \
         secOpsProcessor secOpsProcessorTypes secOpsPipelineProcessorTypes secOpsPipelineConfig; do
  m=$(q "{ $n }" | jq -r '.errors[0].message // "OK"' 2>/dev/null)
  printf '%-34s %s\n' "$n" "$m"
done

echo; echo "== R2: SecOpsPipelineSummary field names =="
for f in feedIDs status version rolloutStatus rolloutState pipelineJSON resourceJSON processorTypes processorCount \
         data payload chronicleName resourceName labels metadata state lastRolloutTime enabled revision \
         processorsCount ingestionMethod ingestionMethods latestVersion currentVersion hash; do
  m=$(q "{ secOpsPipelineSummaries { $f } }" | jq -r '.errors[0].message // "EXISTS"' 2>/dev/null)
  printf '%-34s %s\n' "$f" "$m"
done

echo; echo "== R2: showSecOpsPipelinesPage =="
q '{ showSecOpsPipelinesPage }' | jq -c '.' | head -c 300; echo

echo; echo "== R2: secOpsFeeds metadata (ids + names only) =="
q '{ secOpsFeeds { id displayName } }' | jq -r '.data.secOpsFeeds[]? | [.id,.displayName] | @tsv' | head -40
echo "== Done =="
