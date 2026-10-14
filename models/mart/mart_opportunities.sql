{{
    config(
        materialized='table'
    )
}}

-- Grain: one row per opportunity
-- Reporting-ready opportunity dataset with account context

SELECT
    -- Opportunity identifiers
    opp.opportunity_id,
    opp.account_id,
    opp.opportunity_name,
    -- Account attributes
    acc.account_name,
    acc.segment,
    acc.account_region,
    acc.country,
    acc.industry,
    acc.employee_count,
    acc.account_created_date,
    -- Account lifecycle
    acc.account_status,
    acc.is_customer,
    acc.first_opportunity_created_date,
    acc.first_won_date,
    acc.first_new_business_won_date,
    acc.first_pilot_created_date,
    acc.has_won_pilot,
    acc.has_won_expansion,
    -- Sales ownership
    opp.owner_id,
    opp.owner_name,
    opp.owner_role,
    opp.owner_region,
    -- Acquisition attribution
    opp.opportunity_type,
    opp.lead_source,
    opp.campaign,
    opp.channel,
    opp.channel_owner,
    -- Financial attributes
    opp.amount_local,
    opp.currency,
    opp.probability_pct,
    opp.usd_rate_at_close,
    opp.amount_usd_at_close,
    opp.usd_rate_latest_date,
    opp.amount_usd_latest_date,
    -- Sales pipeline
    opp.stage,
    opp.stage_order,
    opp.stage_label,
    opp.stage_is_open,
    opp.forecast_category,
    opp.is_closed,
    opp.is_won,
    opp.loss_reason,
    -- Dates
    opp.created_date,
    opp.close_date,
    opp.last_activity_date,
    opp.scoping_entered_date,
    -- Sales cycle metrics
    opp.sales_cycle_days,
    opp.days_to_scoping,
    -- Pipeline risk
    opp.is_past_due,
    opp.is_stale,
    opp.is_at_risk,
    opp.is_high_risk

FROM {{ ref('int_opportunities_enriched') }} AS opp

LEFT JOIN {{ ref('int_accounts_enriched') }} AS acc
    ON opp.account_id = acc.account_id
