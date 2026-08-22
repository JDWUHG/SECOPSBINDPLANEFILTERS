# Path to 4.5 TB/month ingestion target

**Target:** 4.5 TB/month = **~151 GB/day**.

## Where we are (updated from the full daily time-series)

Baseline pattern from daily totals 01 Jul–21 Aug 2026:
- Weekday avg **~815 GB/day**, Weekend avg **~401 GB/day**, Blended **~703 GB/day = ~20.9 TB/month**.

Like-for-like signal: **Sat 22 Aug tracked ~63% below a normal Saturday** (60.8 GB by ~09:42,
projecting ~150 GB vs a typical ~401 GB Saturday). Saturday-vs-Saturday, so a fair comparison.

| Point | Volume | TB/month |
|-------|--------|----------|
| **Baseline (before any work)** | ~703 GB/day | **~20.9 TB** |
| **Target** | ~151 GB/day | **4.5 TB** |
| **Required reduction** | — | **~78%** |
| **After today (−63%, projected)** | weekday ~305 / weekend ~150 → blended ~261 GB/day | **~7.8 TB** |

**Status: ~63% cut achieved (≈21 → ≈7.8 TB/month) — about two-thirds of the way to target.**
Confirm with the first full post-change weekday, but the Saturday-vs-Saturday comparison is
already a solid like-for-like read.

**Gap to target: ~3.3 TB/month (~110 GB/day) still to remove.**

## Remaining gap

To reach 4.5 TB from a realistic ~8 TB weekday level, need to remove **~another 3–4 TB/month**.

## Roadmap — safe, no-policy-change wins first

| Priority | Source | Baseline GB/day | Est. saveable GB/day | Action | Status |
|----------|--------|----------------:|---------------------:|--------|--------|
| 1 | ZSCALER_WEBPROXY | 94.7 | ~40 | Deploy parked rules **Z2–Z4** (Google/Apple/CDN) | Built & tested in `DEPLOY_ZSCALER.md` |
| 2 | AWS_VPC_FLOW | 7.4 | ~4 | Drop ACCEPT flows to/from known-good; keep REJECT | Not started |
| 3 | ZSCALER_ZPA / DNS / FIREWALL | ~21 | ~8.5 | Same allowed/no-threat + trusted-domain pattern | Not started |
| 4 | Azure tail (Storage Audit, DocumentDB, misc) | ~28 | ~8.5 | Triage for routine-read/list drops | Not started |

**Rough additional safe saving available: ~61 GB/day ≈ ~1.8 TB/month.**

## The honest arithmetic (firmed up)

- Current projected: **~7.8 TB/month**. Safe remaining wins total **~1.8 TB/month**.
- Safe wins → land around **~6 TB/month**. **Target is 4.5 TB → still ~1.5 TB/month short.**
- **Safe, zero-detection-cost filtering alone will NOT reach 4.5 TB.** This is the honest maths:
  4.5 TB is a ~78% cut; safe filtering gets ~71%.
- Closing the final ~1.5 TB requires the **deferred, higher-risk decisions** we consciously
  declined earlier, each needing sign-off:
  - More aggressive AZURE_SQL (e.g. dropping successful routine DML — needs security sign-off; loses exfil/insider visibility).
  - Zscaler "drop allowed" posture (needs sign-off; loses hunt capability on allowed traffic).
  - Reducing retained CloudTrail writes further.
- **These are business/security policy calls, not engineering.** Do NOT implement them silently to hit a number — they trade away detection capability and must be an accountable decision.

## Recommended sequence

1. **Confirm the real weekday volume** (BL-02) — you may be closer than the conservative estimate.
2. **Deploy Zscaler Z2–Z4** — free, built, ~1 TB/month.
3. **Work the roadmap** (VPC flow, other Zscaler feeds, Azure tail) — safe wins, ~another ~0.8 TB.
4. **Re-measure.** If still above 4.5 TB, escalate the deferred policy decisions with the relevant
   owners — that's the only remaining lever, and it must be a signed choice, not an engineering default.

## Principle to hold

Every reduction so far has been **zero- or low-evidentiary-cost** — noise removed, detection kept.
The last stretch to 4.5 TB may force a choice between the number and detection coverage. When it does,
surface it as a decision, don't bury it in a filter.
