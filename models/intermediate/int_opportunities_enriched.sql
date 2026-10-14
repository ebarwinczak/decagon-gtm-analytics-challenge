{{
    config(
        materialized='table'
    )
}}

WITH opportunities AS (
    SELECT *
    FROM {{ ref('stg_crm__opportunity') }}
),

lead_source_mapping AS (
    SELECT *
    FROM {{ ref('lead_source_channels') }}
),

stage_mapping AS (
    SELECT *
    FROM {{ ref('opportunity_stages') }}
),

fx_rates AS (
    SELECT
        currency,
        rate_month,
        usd_rate
    FROM {{ ref('fx_rates_monthly') }}
)

SELECT
    -- Opportunity identifiers
    opp.opportunity_id,
    opp.account_id,
    opp.opportunity_name,
    -- Sales ownership
    opp.owner_id,
    opp.owner_name,
    opp.owner_role,
    opp.owner_region,
    -- Opportunity classification
    opp.opportunity_type,
    opp.lead_source,
    opp.campaign,
    lead.channel,
    lead.channel_owner,
    -- Financial attributes
    opp.amount_local,
    opp.currency,
    opp.probability_pct,
    -- Historical conversion of amount to USD at time of close (only for closed opportunities)
    fx_close.usd_rate AS usd_rate_at_close,
    (opp.amount_local * fx_close.usd_rate)::DECIMAL(18,2) AS amount_usd_at_close,
    -- Latest date currency conversion (populated for all opportunities) (latest date is latest date IN data)
    fx_latest.usd_rate AS usd_rate_latest_date,
    (opp.amount_local * fx_latest.usd_rate)::DECIMAL(18, 2) AS amount_usd_latest_date,
    -- Sales process
    opp.stage,
    stage.stage_order,
    stage.stage_label,
    stage.is_open AS stage_is_open,
    opp.forecast_category,
    opp.is_closed,
    opp.is_won,
    opp.loss_reason,
    -- Dates
    opp.created_date,
    opp.close_date,
    opp.last_activity_date,
    opp.scoping_entered_date,
    -- Completed sales cycle (closed opportunities only)
    CASE
        WHEN opp.is_closed
            THEN DATE_DIFF('day', opp.created_date, opp.close_date)
    END AS sales_cycle_days,
    -- Time from creation to entering Scoping
    CASE
        WHEN opp.scoping_entered_date IS NOT NULL
            THEN DATE_DIFF('day', opp.created_date,opp.scoping_entered_date)
    END AS days_to_scoping,
     -- Pipeline risk flags: 
    -- Missing dates: track null closed_date and last_activity_date for reference
    (NOT opp.is_closed AND opp.close_date IS NULL) AS is_missing_close_date,
    (NOT opp.is_closed AND opp.last_activity_date IS NULL) AS is_missing_activity_date,
    -- Past due: expected close date has passed
    (NOT opp.is_closed AND COALESCE(opp.close_date < '{{ var("as_of_date") }}'::DATE, FALSE)) AS is_past_due,
    -- Stale: last recorded activity was more than 14 days ago
    (NOT opp.is_closed AND COALESCE(opp.last_activity_date < '{{ var("as_of_date") }}'::DATE - INTERVAL 14 DAYS, FALSE)) AS is_stale,
-- At risk: past due OR stale
    (NOT opp.is_closed
        AND (
            COALESCE(opp.close_date < '{{ var("as_of_date") }}'::DATE, FALSE)
            OR COALESCE(opp.last_activity_date < '{{ var("as_of_date") }}'::DATE - INTERVAL 14 DAYS, FALSE)
            )
    ) AS is_at_risk,
    -- High risk: both past due AND stale
    (NOT opp.is_closed
        AND COALESCE(opp.close_date < '{{ var("as_of_date") }}'::DATE, FALSE)
        AND COALESCE(opp.last_activity_date < '{{ var("as_of_date") }}'::DATE - INTERVAL 14 DAYS, FALSE)
    ) AS is_high_risk

FROM opportunities AS opp

LEFT JOIN lead_source_mapping AS lead
    ON opp.lead_source = lead.lead_source

LEFT JOIN stage_mapping AS stage
    ON opp.stage = stage.stage

-- Historical FX rate for closed opportunities
LEFT JOIN fx_rates AS fx_close
    ON opp.currency = fx_close.currency
        AND DATE_TRUNC('month', opp.close_date) = fx_close.rate_month 
        AND opp.is_closed = TRUE

-- Latest FX rate using the the latest date in data (defined as var in dbt_project.yml)
LEFT JOIN fx_rates AS fx_latest
    ON opp.currency = fx_latest.currency
        AND DATE_TRUNC('month', '{{ var("as_of_date") }}'::DATE) = fx_latest.rate_month
