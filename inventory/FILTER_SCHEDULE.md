# BindPlane SecOps Filtering — Work Schedule & Ingestion Savings

**Instance:** `app.bindplane.com` · **Project:** Google SecOps UK (`01KC4W80ECMCJ8QJ9AG85S9S5J`)
**Target:** 4.5 TB/month ingestion · **Baseline:** ~19.9 TB/month (all sources) / ~21 TB/month peak

> Units: decimal TB (GB ÷ 1000³, matching the SecOps ingestion query). Daily = 30-day total ÷ 30;
> monthly = daily × 30.44. Savings estimates are structural until confirmed by BL-02 (weekday measure).

---

## 1. WORK DONE (deployed & verified)

| Date | Log source | What was filtered | Cut | Saved TB/mo | Verify |
|------|-----------|-------------------|-----|-------------|--------|
| 21 Aug | MICROSOFT_INSIGHTS_COMPONENTS | Source removed entirely | 100% | ~0.83 | Confirmed 0 GB/day |
| 22 Aug | AZURE_SQL | Drop diagnostic/perf/health categories (R1) + BATCH STARTED (R2) + Azure Monitor metrics (R3); redact SQL statement text | ~92% | ~5.74 | JSON-verified; BL-01 (redaction output) open |
| 22 Aug | AWS_CLOUDTRAIL | Drop `readOnly:true` (Rule A) + `invokedBy` AWS-service automation (Rule B), on top of existing name-list rules | ~80% | ~5.20 | JSON-verified byte-for-byte |
| 22 Aug | ZSCALER_WEBPROXY | Rule Z1 — drop allowed + no-threat browsing to Microsoft/Office/Windows/Azure (plus existing Darktrace rule) | partial | ~0.4 | JSON-verified |
| **Total banked** | | | | **~12.2 TB/mo** | |

**Post-work run-rate (Sat 22 Aug, like-for-like vs a normal Saturday): ~63% overall reduction.**
Projected new run-rate ~7.8–8 TB/month (confirm on first full weekday — BL-02).

---

## 2. WORK SCHEDULE (planned BindPlane changes)

All are **Filter by Regex** processors (Action `Exclude`, Match `Body`, Field empty) on the named
SecOps pipeline, unless noted. Full paste-ready regexes in `../pipelines/REMAINING_TARGETS_SPEC.md`.

| ID | When | Log source | Processor to add | Cut | Saved TB/mo | Ready? |
|----|------|-----------|------------------|-----|-------------|--------|
| T2 | **23 Aug** | ZSCALER_WEBPROXY | Z2 Google, Z3 Apple, Z4 CDN (allowed+no-threat) | +45% | ~1.30 | ✅ built & tested |
| T1 | on sample+signoff | AWS_WAF | Drop `action=ALLOW` (keep BLOCK/COUNT) | 75% | ~1.49 | ⚠️ needs 1 sample + sign-off |
| T3 | phase 2 | ZSCALER_ZPA | Drop allowed + no-threat | 40% | ~0.09 | confirm feed fields |
| T4 | phase 2 | AWS_VPC_FLOW | Drop ACCEPT, keep REJECT | 55% | ~0.12 | ⚠️ needs 1 sample |
| T5 | phase 2 | ZSCALER_DNS | Drop trusted-domain resolutions | 40% | ~0.09 | confirm field |
| T6 | phase 2 | ZSCALER_FIREWALL | Drop allowed/permitted flows | 45% | ~0.08 | confirm value |
| T7 | phase 2 | AZURE_STORAGE_AUDIT | Drop routine read/get/list ops | 55% | ~0.07 | confirm field |
| T8 | phase 2 | AZURE_DOCUMENTDB | Drop routine data-plane reads | 45% | ~0.05 | confirm field |
| T9 | phase 2 | AZURE_WAF | Drop ALLOW, keep BLOCK | 60% | ~0.02 | confirm field |
| T10 | phase 2 | GCP_CLOUDAUDIT | Drop read-only / DATA_READ | 50% | ~0.00 | confirm structure |
| — | phase 2 | AZURE_DATAPLANE / NSG_FLOW / FIREWALL / ServiceBus / Barracuda | Drop request/allow/read noise | ~40% | ~0.10 | assess per source |
| **Total planned** | | | | | **~3.4 TB/mo** | |

---

## 3. TARGET INGESTION SAVINGS (running total to 4.5 TB/mo)

| Stage | TB/month | Note |
|-------|---------:|------|
| Baseline (all sources) | ~19.9 | pre-any-work |
| After work DONE (section 1) | **~7.8** | ~63% cut, deployed 21–22 Aug |
| After T2 (Zscaler Z2–Z4) | ~6.9 | ready now |
| After T1 (AWS_WAF ALLOW) | **~5.5** | biggest single remaining lever |
| After T3–T10 + tail (phase 2) | **~4.7** | long tail of smaller wins |
| **Target** | **4.5** | |

**Verdict:** completing the full schedule lands ~4.7 TB/mo — essentially at target. **T1 + T2 deliver
the vast majority of the remaining gain; T3–T10 are a ~0.3 TB tail.** Margin to 4.5 is thin — if AWS_WAF
is less ALLOW-heavy than the 75% assumption, expect to land nearer 5 TB and the deferred higher-risk
options (aggressive Azure SQL / Zscaler drop-allowed) would need sign-off to close the last gap.

---

## 4. OPEN ITEMS (housekeeping — no volume impact)

| ID | Item |
|----|------|
| BL-01 | Verify AZURE_SQL redaction blanks only the statement value, not the key label (check one live event) |
| BL-02 | Measure actual reduction on first full weekday (turns estimates into real numbers) |
| BL-03 | Confirm no live detection depends on `Blocks`/`Deadlocks` (Azure SQL) — Cyber Defence |
| BL-04 | Decide: drop `Errors` category or keep (Azure SQL) |
| BL-06 | Rotate the BindPlane API keys shared during setup |
| BL-08 | Confirm single vs multiple Zscaler feeds (filters are per-feed) |

---

*Detailed rule definitions and rationale: `../pipelines/*.json`, `AZURE_SQL_FILTER_DESIGN.md`,
`DEPLOY_*.md`, `REMAINING_TARGETS_SPEC.md`, `PATH_TO_4.5TB.md`. Live verified states:
`*_LIVE*.json`.*
