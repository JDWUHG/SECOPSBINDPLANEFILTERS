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

echo "== Done. Output in $OUT =="
