{{
    config(
        materialized='table'
    )
}}

-- Grain: one row per stage and segment
-- Current open pipeline and risk exposure as of the reporting date

SELECT
    stage,
    stage_order,
    segment,
    -- Open pipeline volume
    COUNT(*) AS open_opportunities,
    -- Open pipeline value in USD
    SUM(amount_usd_latest_date) AS open_pipeline_usd,
    -- Pipeline at risk (past due OR stale)
    COUNT(*) FILTER (WHERE is_at_risk) AS at_risk_opportunities,
    COALESCE(SUM(amount_usd_latest_date) FILTER (WHERE is_at_risk), 0) AS at_risk_pipeline_usd,
    -- Higher-risk subset (past due AND stale)
    COUNT(*) FILTER (WHERE is_high_risk) AS high_risk_opportunities,
    COALESCE(SUM(amount_usd_latest_date) FILTER (WHERE is_high_risk), 0) AS high_risk_pipeline_usd,
    -- Risk breakdown
    COUNT(*) FILTER (WHERE is_past_due) AS past_due_opportunities,
    COUNT(*) FILTER (WHERE is_stale) AS stale_opportunities

FROM {{ ref('mart_opportunities') }}
WHERE is_closed = FALSE
GROUP BY
    stage,
    stage_order,
    segment
    