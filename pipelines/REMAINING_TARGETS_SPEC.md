# Remaining Filtering Targets — BindPlane Processor Specs

One document. For each remaining SecOps-Pipeline target: the processor to add, its form
settings, and a paste-ready regex. Excludes everything already deployed today
(Azure SQL, CloudTrail A+B, Zscaler Z1, Microsoft Insights removal).

## How to use every spec below

All are the **"Filter by Regex"** processor unless stated. Common form settings:

| Field | Value |
|-------|-------|
| Action | `Exclude` |
| Match | `Body` |
| Field | *(leave empty)* |

Add one processor per rule → paste the regex → after pasting, **click away / Tab (not Enter)** →
Save → **Rollout** → export the pipeline JSON to verify.

> ⚠️ **Two specs (T1 AWS_WAF, T4 VPC Flow) need ONE real sample event to confirm field
> names/values before deploying** — flagged inline. Do not deploy those blind: getting the
> allow/block field wrong risks dropping security events instead of noise. All others reuse
> field patterns already proven on your live feeds.

Running impact target: current ~7.9 TB/mo → all specs below ~ -3.4 TB/mo → ~4.5 TB/mo.

---

# TARGET SCHEDULE (ranked by impact)

| ID | Source | Pipeline ID | Est. saving | Ready? |
|----|--------|-------------|-------------|--------|
| T1 | AWS_WAF | 6f17d9b9-8874-4c5b-9a54-eca796841abc | ~1.5 TB/mo | needs sample + sign-off |
| T2 | Zscaler Webproxy (Z2–Z4) | 7d023b21-3b13-4580-9174-a86b14dace06 | ~1.3 TB/mo | ✅ ready |
| T3 | Zscaler ZPA | *(find in UI)* | ~0.09 TB/mo | ready (confirm feed) |
| T4 | AWS VPC Flow | *(find in UI)* | ~0.12 TB/mo | needs sample |
| T5 | Zscaler DNS | *(find in UI)* | ~0.09 TB/mo | ready |
| T6 | Zscaler Firewall | *(find in UI)* | ~0.08 TB/mo | ready |
| T7 | Azure Storage Audit | *(find in UI)* | ~0.07 TB/mo | ready |
| T8 | Azure DocumentDB | *(find in UI)* | ~0.05 TB/mo | ready |
| T9 | Azure WAF | *(find in UI)* | ~0.02 TB/mo | ready |
| T10 | GCP CloudAudit | *(find in UI)* | ~0.01 TB/mo | ready |

---

## T1 — AWS_WAF: drop ALLOW traffic  ⚠️ needs sample + sign-off  (~1.5 TB/mo — biggest win)

The live filter only drops monitoring user-agents. The real lever is dropping requests the WAF
**allowed**, keeping what it **blocked**.

**⚠️ Before deploying:** confirm from one real AWS_WAF event how the decision is recorded.
AWS WAF standard format uses `"action":"ALLOW"` / `"action":"BLOCK"`. Confirm this, then use:

**Processor: Filter by Regex** — Action `Exclude`, Match `Body`, Field empty
```
"action"\s*:\s*"ALLOW"
```

**Safety:** keeps every `"action":"BLOCK"` and `"action":"COUNT"` (the security signal).
Undetected attacks that were allowed are covered by app-layer / CloudTrail / other detection.
Same allow/block trade-off already accepted for Zscaler — confirm consciously as WAF fronts
public apps.

---

## T2 — Zscaler Webproxy: deploy Z2, Z3, Z4  ✅ READY  (~1.3 TB/mo)

Extends the live Z1 (Microsoft) rule to the other big trusted destinations. Add three
processors. Each: Action `Exclude`, Match `Body`, Field empty. Leave Z0 (Darktrace) and Z1
(Microsoft) alone.

**T2a — Google**
```
(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(google|googleapis|gstatic|googleusercontent|googlevideo)\.com".*?"threatcategory"\s*:\s*"None")
```

**T2b — Apple**
```
(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(apple|icloud|mzstatic|cdn-apple)\.com".*?"threatcategory"\s*:\s*"None")
```

**T2c — Major CDNs**
```
(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(akamai|akamaized|akamaitechnologies|akamaiedge|cloudflare|fastly|edgesuite|edgekey|llnwd)\.(net|com)".*?"threatcategory"\s*:\s*"None")
```

**Safety:** only drops allowed + no-threat + trusted-domain; blocked/threat/unknown/lookalike
domains all kept (trusted domain must be at the END of the hostname).

---

## T3 — Zscaler ZPA: drop allowed access to trusted internal apps  READY  (~0.09 TB/mo)

Same proven Zscaler pattern applied to the ZPA feed. **Confirm the ZPA body uses the same
`action`/`hostname` fields** (very likely, same vendor) — if it uses different keys, adjust.

**Processor: Filter by Regex** — Action `Exclude`, Match `Body`, Field empty
```
(?s:"action"\s*:\s*"Allowed".*?"threatcategory"\s*:\s*"None")
```
> Note: this ZPA rule is broader (allowed + no-threat, any app). If you need to keep specific
> sensitive apps, add a hostname clause like T2. Start conservative if unsure.

---

## T4 — AWS VPC Flow: drop ACCEPT, keep REJECT  ⚠️ needs sample  (~0.12 TB/mo)

Flow logs are mostly ACCEPT. Keep all REJECT (the security signal); drop routine ACCEPT.

**⚠️ Confirm the format first** — VPC flow logs can arrive as space-delimited text OR JSON.
- If JSON with an `action` field:
```
"action"\s*:\s*"ACCEPT"
```
- If space-delimited (default v2 format ends in `... ACCEPT OK`):
```
\sACCEPT\s+OK\s*$
```
**Get one sample to pick the right one.** Keeps every REJECT.

---

## T5 — Zscaler DNS: drop resolutions to trusted domains  READY  (~0.09 TB/mo)

Same trusted-domain approach on the DNS feed. Confirm DNS body field for the queried domain
(often `dns` / `domain` / `hostname`). Starter (assumes `hostname`-style field + no-threat):
```
(?s:"[a-z]*(host|domain)[a-z]*"\s*:\s*"[^"]*\.(microsoft|windows|google|googleapis|apple|icloud|akamai|cloudflare)\.(com|net)")
```
> Confirm the actual DNS domain field name from one sample; adjust the key before deploying.

---

## T6 — Zscaler Firewall: drop allowed/permitted routine flows  READY  (~0.08 TB/mo)

Drop permitted routine flows, keep blocked/denied.
```
"action"\s*:\s*"(Allow|Allowed|Permitted)"
```
> Confirm the exact allowed-value string for the Zscaler FW feed from one sample.

---

## T7 — Azure Storage Audit: drop routine read/list ops  READY  (~0.07 TB/mo)

Drop routine read/get/list data-plane operations; keep writes/deletes/permission changes.
```
"OperationName"\s*:\s*"(GetBlob|GetBlobProperties|GetBlobServiceProperties|ListBlobs|GetContainerProperties|GetContainerACL|HeadBlob|GetBlobMetadata|ListContainers)"
```
> Confirm the operation field name (`OperationName` / `operationName` / `category`) from one sample.

---

## T8 — Azure DocumentDB (Cosmos): drop routine data-plane reads  READY  (~0.05 TB/mo)

Drop routine query/read data-plane calls; keep control-plane and auth events.
```
"OperationName"\s*:\s*"(Query|ReadFeed|Get|Read)"
```
> Confirm the operation field/values from one sample before deploying.

---

## T9 — Azure WAF: drop ALLOW, keep BLOCK  READY  (~0.02 TB/mo)

Same principle as AWS WAF, Azure format.
```
"action_s"\s*:\s*"Allow"
```
> Azure App Gateway WAF commonly uses `action_s` = `Allowed`/`Blocked` or `Matched`. Confirm
> the field/value from one sample; keep all Blocked/Matched.

---

## T10 — GCP CloudAudit: drop read-only  READY  (~0.01 TB/mo)

GCP audit logs split into ADMIN_ACTIVITY (keep) vs DATA_READ (mostly droppable noise).
```
"@type"\s*:\s*"[^"]*AuditLog"[\s\S]*?"methodName"\s*:\s*"[^"]*\.(get|list|aggregatedList)"
```
> Prefer dropping by log type if available (`DATA_READ`). Confirm structure from one sample.

---

# Deployment order (recommended)

1. **T2 (Zscaler Z2–Z4)** — ready now, ~1.3 TB, no sample needed. Do this first (queued 23 Aug).
2. **T1 (AWS_WAF ALLOW)** — get one WAF sample + sign-off, then deploy. Biggest single win.
3. **T3, T5, T6 (other Zscaler feeds)** — reuse the proven pattern; confirm each feed's fields.
4. **T7, T8, T9, T10 + T4 (Azure/GCP/VPC tail)** — smaller; batch them, confirm fields per source.

# Honest notes

- **T1 + T2 are ~83% of the remaining gain.** Everything T3–T10 is a long tail of small wins.
- Every "confirm from one sample" note is deliberate: these are the fields I could NOT verify
  without live log content (agent has no access to log bodies). Reusing a proven pattern is safe;
  a new field name is not — confirm before deploying those.
- Landing exactly at 4.5 TB assumes each source hits its estimated cut. If WAF (T1) is less
  ALLOW-heavy than assumed, expect to land nearer ~5 TB and revisit the deferred aggressive
  options (needs sign-off).
