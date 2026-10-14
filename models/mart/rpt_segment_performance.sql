{{
    config(
        materialized='table'
    )
}}

-- Grain: one row per segment and opportunity type
-- Measures closed-deal conversion and closed-won value by segment

WITH segment_performance AS (
    SELECT
        segment,
        opportunity_type,
        COUNT(*) AS total_opportunities,
        COUNT(*) FILTER (WHERE is_closed) AS closed_opportunities,
        COUNT(*) FILTER (WHERE is_closed AND is_won) AS won_opportunities,
        COUNT(*) FILTER (WHERE is_closed AND NOT is_won) AS lost_opportunities,
        SUM(amount_usd_at_close) FILTER (WHERE is_closed AND is_won) AS closed_won_usd,
        -- Median sales cycle for won opportunities
        MEDIAN(sales_cycle_days) FILTER (WHERE is_closed AND is_won) AS median_won_sales_cycle_days

    FROM {{ ref('mart_opportunities') }}

    GROUP BY
        segment,
        opportunity_type
)

SELECT
    segment,
    opportunity_type,
    total_opportunities,
    closed_opportunities,
    won_opportunities,
    lost_opportunities,
    ROUND((won_opportunities / NULLIF(closed_opportunities, 0)) * 100, 2) AS win_rate_pct,
    COALESCE(closed_won_usd, 0) AS closed_won_usd,
    median_won_sales_cycle_days

FROM segment_performance
