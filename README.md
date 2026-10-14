# Decagon GTM Analytics

This dbt project models Decagon's CRM accounts and opportunities in dbt's three layers: staging (light cleanup of the raw CRM data), intermediate (business logic) and marts (reporting tables). It answers two questions from GTM leadership: **which channels and segments produce pipeline that closes**, and **where pipeline sits now and what's at risk**. It covers 4,722 CRM opportunities across 3,000 accounts, Oct 2023 – Sep 28, 2026. Charts and findings are summarized on one slide: `docs/decagon-gtm-analytics-project.pdf`.

## What the data says

1. **Enterprise brings the most New Business value but is the hardest to win:** $42.1M closed-won, a 19% win rate and a 169-day median cycle. Most losses go to a competitor (27%) or no decision (23%), and lost deals stay open nearly as long as won ones (153 vs 169 days), so the effort is spent before the loss. In Expansion, Mid-Market brings the most value ($10.1M) and SMB wins most often (73%).
2. **Inbound and Outbound bring the volume (56% of New Business won); Referrals (47%) and Partners (35%) convert best.** Paid search, the one directly paid source, wins 13% of New Business deals (website leads: 34%), pulling Inbound's rate from 30% to 25%.
3. **Open pipeline is $104.0M, 83% of it Enterprise.** Pilot is the largest stage ($25.7M), and $20.3M (99 deals) is already past its expected close date.
4. **$35.2M (34%) of open pipeline is at risk, and most of it is Enterprise.** 37% of open Enterprise deals are flagged, against 15% for Mid-Market and 3% for SMB. Enterprise Pilot and Negotiation deals alone hold $23.0M: the place to start a pipeline review.

An ad-hoc analysis also found that a won pilot lifts the New Business win rate from 28% to 35% (pilots matched to deals by account and timing, since the CRM doesn't link them).

## How the model is built

| Layer | Models | Grain | Job |
|---|---|---|---|
| Seeds | `account`, `opportunity` + `lead_source_channels`, `opportunity_stages`, `fx_rates_monthly` | | Raw CRM extracts, plus business-owned lookups RevOps can edit without SQL |
| Staging | `stg_crm__account`, `stg_crm__opportunity` | account / opp | Light cleanup only: rename, cast, null out blanks. No business logic. |
| Intermediate | `int_opportunities_enriched`, `int_accounts__customer_history`, `int_accounts_enriched` | opp / account | Channel, stage order, USD amounts, cycle days, risk flags. Customer status defined once. |
| Mart | `mart_opportunities`, `mart_accounts` | opp / account | Reporting tables. Every metric is computable from `mart_opportunities`. |
| Reports | `rpt_segment_performance`, `rpt_channel_performance`, `rpt_pipeline_health` | segment × type, channel × type, stage × segment | One per part of the two questions |

**55 automated checks run on every build.** They confirm that every account and opportunity ID is unique and filled in, every opportunity belongs to a real account, every stage and lead source has a mapping, a deal marked Closed Won is always flagged as won, and every deal has an exchange rate. We don't control the CRM's structure, so a new stage, lead source or currency stops the build instead of silently dropping deals from the totals.

**Scaling as the data grows.** A new source (marketing spend, stage history) gets its own staging model and joins at the intermediate layer, with nothing downstream rewritten. Marts keep a fixed grain (one row per opportunity, one per account), so a new metric is a new aggregation of an existing table, and a new channel or stage is a one-row seed edit. Moving to a cloud warehouse (Snowflake, BigQuery, Databricks) means changing the connection profile and replacing the `account` and `opportunity` seeds with sources that read the replicated CRM tables. Separately, the largest tables can switch to incremental builds as volume grows.

## Metric definitions

| Metric | How it's calculated | Why this way |
|---|---|---|
| **Win rate** | Won ÷ (won + lost), counting closed opportunities only | Open deals are left out because their outcome isn't known yet. In the charts and findings, each opportunity type gets its own rate: Expansion wins far more often, so a combined rate would read 35% when New Business wins 28%, and would shift with the deal mix. Not limited to qualified deals, since 94–97% get past Discovery anyway. |
| **Cycle length** | Median days from created to closed, for won deals, by segment | SMB wins close in a median of 52 days, Enterprise in 169. A company-wide figure (86 days) matches neither, and would lengthen just because more Enterprise deals closed, even if no segment slowed. The median resists a few very long deals. |
| **Channel performance** | Closed-won $ and win rate for each channel, by deal type | Measured on closed-won rather than pipeline created: Outbound created the most closed pipeline ($116.6M) but wins 23% of its New Business deals, below the 28% average. |
| **Open & at-risk pipeline** | Open deal value in USD. **At risk** = open, and either the close date is before the reporting date (9/28/2026, the latest creation date in the data) or 14+ days have passed from `last_activity_date` to the reporting date. **High risk** = both. | 99 deals are past due and 87 are stale, but only 27 are both, so requiring both would miss most of the 159 flagged. Flags prompt a review, not a predicted loss. |

*Caveat on recent quarters:* fast-closing deals are mostly SMB, which wins more often, so recent quarters' closed deals lean SMB and their win rates look better than they'll end up. Overall the effect is tiny (27.8% vs 27.5% for deals 9+ months old), but quarterly trends should skip quarters whose deals haven't had time to close.

**Field definitions:** every column in every model is defined in the model YAML files (browse them with `dbt docs generate` and `dbt docs serve`). The `lead_source` → `channel` mapping is in the `lead_source_channels` seed.

## Assumptions

- **Reporting date ("as-of date") = 2026-09-28** (`var('as_of_date')`). It's the latest date in the data: the most recent created date and last activity date (close dates run later only because open deals carry future expected dates).
- **Exchange rates are FRED monthly averages:** [EXUSEU](https://fred.stlouisfed.org/series/EXUSEU) (USD per EUR) and [EXUSUK](https://fred.stlouisfed.org/series/EXUSUK) (USD per GBP). Using the close-month rate means past results don't change when currencies move.
- **A customer is an account that has won at least one New Business deal.** Pilots are trials, so an account with only won pilots doesn't count as a customer yet.
- **Customer Referral is a fifth channel.** It's a warm introduction with no spend behind it, and folding it into Partners would lift Partners from 35% to 40%.
- **Paid Search is grouped under Inbound.** Its lead source stays available as a sub-channel for drill-down.
- **Inferred, to confirm with RevOps:** `channel_owner` (defined in the `lead_source_channels` seed, based on common B2B practice), stage order (the standard sales sequence, in the `opportunity_stages` seed; CRM win probability rises in the same order), and calendar quarters.

## What's missing

| Can't answer | Why it matters | Data needed |
|---|---|---|
| Where deals stall | We only see where deals are now, not whether Pilot is a bottleneck or how often close dates slip | Stage and close-date change history (CRM field history; records only from when it's enabled) |
| Cost per dollar won (CAC, ROI) | Referrals and Partners convert best, but without cost we can't say where the next dollar should go | Spend by channel and campaign, by month |
| Which touches influenced a deal | Each deal credits one source, so earlier events or content get no credit | Campaign membership and contact touchpoints |
| Whether pilots cause deals | Won pilots coincide with higher win rates, but are matched only by account and timing | A "converted from pilot" link |
| Coverage against plan | Whether $104M is enough depends on what each team must close | Quota and targets by segment and quarter |
| Revenue, not bookings | Closed-won isn't ARR: it ignores contract length and renewals | Contract value, term and ARR; Finance's FX rates |

## What I'd build next

1. **A daily pipeline snapshot** (`dbt snapshot` on opportunities). The data is current-state only, so every day without one is history lost. Within a quarter it gives time in stage, slippage and conversion, turning "at risk" from a flag into evidence.
2. **A pilot → New Business model,** once the link field exists, so pilot outcomes become an early forecast signal.
3. **Channel efficiency:** add spend to `rpt_channel_performance` to show where the next marketing dollar goes.

**Running it:** install `dbt-duckdb`, then run `dbt build` (uses the included `profiles.yml`).
