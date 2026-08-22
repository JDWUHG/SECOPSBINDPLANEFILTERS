# Path to 4.5 TB/month ingestion target

**Target:** 4.5 TB/month = **~151 GB/day**.

## Where we are

| Point | Volume | TB/month |
|-------|--------|----------|
| **Baseline (before any work)** | ~710 GB/day | **~21.1 TB** |
| **Target** | ~151 GB/day | **4.5 TB** |
| **Required reduction** | — | **~79%** |
| **After today (partial-Saturday estimate)** | ~197 GB/day | ~5.9 TB |
| **After today (realistic weekday estimate)** | ~260–395 GB/day | **~8–12 TB** |

**Status: major progress (~21 → ~6–10 TB/month), but NOT yet at 4.5 TB.**
Roughly half to two-thirds of the gap is closed. Confirm the true figure on a **full weekday**
before deciding how much more is needed — today's snapshot was a partial weekend morning and
under-represents a normal day.

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

## The honest arithmetic

- Safe wins above get you roughly **~1.8 TB/month** further → likely lands you around **~6 TB/month** on a weekday.
- **That may still be short of 4.5 TB.** Closing the final gap likely requires the **deferred, higher-risk decisions** we consciously declined earlier, each needing sign-off:
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
