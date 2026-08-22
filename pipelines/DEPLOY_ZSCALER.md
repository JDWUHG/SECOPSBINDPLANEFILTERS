# Deploying the ZSCALER_Filter additions

Adds 4 new "Filter by Regex" processors that drop **allowed, no-threat** browsing to
major trusted vendor / CDN / update domains — the bulk of web-proxy noise. Each one is
an exact clone of the existing (proven, live) Darktrace rule's shape, with only the
hostname pattern changed. No new fields, no guessing.

**Pipeline:** `ZSCALER_Filter`
**Edit here:** https://app.bindplane.com/p/01KC4W80ECMCJ8QJ9AG85S9S5J/secops-pipelines/7d023b21-3b13-4580-9174-a86b14dace06
**Rollback:** the current single-rule state is preserved in `zscaler_filter.json` (rule Z0). Screenshot/export before editing.

## What these rules do (plain English)

Each rule drops a log entry ONLY when ALL three are true:
1. `action` = `Allowed` (blocked traffic is untouched)
2. `hostname` ends in a trusted domain (Microsoft / Google / Apple / CDN)
3. `threatcategory` = `None` (anything with any threat flag is untouched)

**Safety:** verified against evasion tests — a lookalike like `microsoft.com.attacker.ru`
is KEPT (not dropped), because the trusted domain must be at the END of the hostname.
Blocked traffic, threats, and unknown domains all survive.

## Form settings — same for every rule

| Field | Value |
|---|---|
| **Action** | `Exclude` |
| **Match** | `Body` |
| **Field** | *(leave empty)* |

## Add these 4 processors (one regex each)

### Z1 — Microsoft / Office / Windows / Azure
Short Description: `Drop allowed no-threat browsing to Microsoft/Office/Windows/Azure`
```
(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(microsoft|office|office365|windows|windowsupdate|azure|azureedge|msftconnecttest|msedge|live|microsoftonline)\.(com|net)".*?"threatcategory"\s*:\s*"None")
```

### Z2 — Google
Short Description: `Drop allowed no-threat browsing to Google`
```
(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(google|googleapis|gstatic|googleusercontent|googlevideo)\.com".*?"threatcategory"\s*:\s*"None")
```

### Z3 — Apple
Short Description: `Drop allowed no-threat browsing to Apple`
```
(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(apple|icloud|mzstatic|cdn-apple)\.com".*?"threatcategory"\s*:\s*"None")
```

### Z4 — CDN / edge infrastructure
Short Description: `Drop allowed no-threat browsing to major CDNs`
```
(?s:"action"\s*:\s*"Allowed".*?"hostname"\s*:\s*"[^"]*\.(akamai|akamaized|akamaitechnologies|akamaiedge|cloudflare|fastly|edgesuite|edgekey|llnwd)\.(net|com)".*?"threatcategory"\s*:\s*"None")
```

## Steps

1. Open the pipeline URL, export/screenshot current state (rollback).
2. Leave the existing Darktrace rule (Z0) alone.
3. Add 4 new "Filter by Regex" processors, one per Z1–Z4 above. Action=Exclude, Match=Body, Field empty.
   - After pasting each regex, click away / Tab — do NOT press Enter (that appended stray characters on earlier rules).
4. Save → **Rollout** (editing alone does not deploy).
5. Paste the pipeline JSON export back so the result can be verified byte-for-byte.

## Not included yet (needs one real sample)

- **Drop all blocked traffic** — you review blocked in the Zscaler console, so it needn't sit in SecOps.
  Not built because the exact `action` value for blocked (`Blocked`? `Denied`?) is unconfirmed.
  Add one rule for it once a single real Zscaler event confirms the value.
- **Wider trusted-domain coverage / risk-scored / large-transfer logic** — deferred; some of it
  needs numeric/parsed fields that can't be matched by regex on the raw string body.

## Reminder

An `action=Allowed` + trusted-domain + `threatcategory=None` drop assumes the field ORDER
(action → hostname → threatcategory) is stable, exactly as the live Darktrace rule already
assumes. This is proven on the current feed. If Zscaler ever reorders these fields, the rules
would silently stop matching (fails safe — keeps data, loses reduction). Re-verify after any
Zscaler feed/format change.
