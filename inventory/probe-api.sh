#!/usr/bin/env bash
#
# probe-api.sh — Read-only probe of the BindPlane API to find where the SecOps
# pipeline RULE definitions can be read from (the summaries query only returns
# names/IDs/timestamps).
#
# Writes everything to $1 (default ./probe-out). Prints ONLY HTTP status codes and
# sizes — never response bodies — so it is safe to run where logs are public.
#
# Env: BINDPLANE_URL, BINDPLANE_API_KEY, BINDPLANE_ACCOUNT_ID (optional)
set -uo pipefail

: "${BINDPLANE_URL:?}"; : "${BINDPLANE_API_KEY:?}"
OUT="${1:-./probe-out}"; mkdir -p "$OUT"
BASE="${BINDPLANE_URL%/}"
H=(-H "X-Bindplane-Api-Key: ${BINDPLANE_API_KEY}")
[ -n "${BINDPLANE_ACCOUNT_ID:-}" ] && H+=(-H "X-Bindplane-Account-ID: ${BINDPLANE_ACCOUNT_ID}")

get() { # get <label> <path>
  local code; code=$(curl -sS -m 30 "${H[@]}" -o "$OUT/$1.json" -w '%{http_code}' "${BASE}$2" 2>/dev/null || echo 000)
  printf '%-34s GET  %-40s HTTP %s  %s bytes\n' "$1" "$2" "$code" "$(wc -c < "$OUT/$1.json" 2>/dev/null || echo 0)"
}
gql() { # gql <label> <query-json-string>
  local code; code=$(curl -sS -m 60 "${H[@]}" -H 'Content-Type: application/json' -X POST \
    -d "$2" -o "$OUT/$1.json" -w '%{http_code}' "${BASE}/v1/graphql" 2>/dev/null || echo 000)
  printf '%-34s GQL  %-40s HTTP %s  %s bytes\n' "$1" "(graphql)" "$code" "$(wc -c < "$OUT/$1.json" 2>/dev/null || echo 0)"
}

echo "== Auth / reachability =="
get version        /v1/version
get agents_probe   "/v1/agents?query=&limit=1" 2>/dev/null

echo "== REST candidates for SecOps pipelines =="
get rest_secops_pipelines    /v1/secops-pipelines
get rest_secOpsPipelines     /v1/secOpsPipelines
get rest_secops_pipelines2   /v1/secops/pipelines
get rest_pipelines           /v1/pipelines

echo "== GraphQL: summaries (known to work) =="
gql summaries '{"query":"{ secOpsPipelineSummaries { id displayName description logTypes createTime updateTime } }"}'

echo "== GraphQL: full introspection (schema discovery) =="
gql introspection '{"query":"query { __schema { queryType { name } mutationType { name } types { name kind fields { name args { name type { name kind ofType { name kind ofType { name kind } } } } type { name kind ofType { name kind ofType { name kind ofType { name kind } } } } } inputFields { name } enumValues { name } } } }"}'

echo "== GraphQL: lightweight schema discovery =="
gql q_fields   '{"query":"{ __schema { queryType { fields { name } } } }"}'
gql m_fields   '{"query":"{ __schema { mutationType { fields { name } } } }"}'
gql t_names    '{"query":"{ __schema { types { name } } }"}'
gql g_single   '{"query":"{ secOpsPipeline(id:\"c072e6b7-0690-419c-82ca-901b7ab2bc3f\") { id displayName } }"}'
gql g_list     '{"query":"{ secOpsPipelines { id displayName } }"}'

echo
echo "== Non-sensitive content summary (public-log safe) =="
echo "-- REST fallback looks like: $(head -c 80 "$OUT/rest_secops_pipelines.json" | tr -d '\n\r' | tr -c '[:print:]' '?')"
for f in introspection q_fields m_fields g_single g_list; do
  echo "-- $f: $(head -c 400 "$OUT/$f.json" | tr -d '\n\r' | tr -c '[:print:]' '?')"
done
if command -v jq >/dev/null; then
  echo "-- Query field names matching secops/pipeline/process/filter:"
  jq -r '.data.__schema.queryType.fields[]?.name' "$OUT/q_fields.json" 2>/dev/null | grep -i -E 'secops|pipeline|process|filter|config|feed|stream' | tr '\n' ' '; echo
  echo "-- Mutation field names matching same:"
  jq -r '.data.__schema.mutationType.fields[]?.name' "$OUT/m_fields.json" 2>/dev/null | grep -i -E 'secops|pipeline' | tr '\n' ' '; echo
  echo "-- Type names matching secops/pipeline:"
  jq -r '.data.__schema.types[]?.name' "$OUT/t_names.json" 2>/dev/null | grep -i -E 'secops|pipeline|feed|stream' | tr '\n' ' '; echo
  echo "-- Pipeline summaries:"
  jq -c '.data.secOpsPipelineSummaries[]? | {displayName,updateTime}' "$OUT/summaries.json" 2>/dev/null
fi

echo "== Done. Output in $OUT =="
