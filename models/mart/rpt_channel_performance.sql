{{
    config(
        materialized='table'
    )
}}

-- Grain: one row per channel and opportunity type
-- Measures channel performance using realized closed-deal outcomes

WITH opportunities AS (
    SELECT
        opportunity_id,
        channel,
        opportunity_type,
        is_closed,
        is_won,
        amount_usd_at_close

    FROM {{ ref('mart_opportunities') }}
),

channel_performance AS (
    SELECT
        channel,
        opportunity_type,
        -- Opportunity volume
        COUNT(*) AS total_opportunities,
        COUNT(*) FILTER (WHERE is_closed = TRUE) AS closed_opportunities,
        COUNT(*) FILTER (WHERE is_closed = TRUE AND is_won = TRUE) AS won_opportunities,
        COUNT(*) FILTER (WHERE is_closed = TRUE AND is_won = FALSE) AS lost_opportunities,
        -- Value of won opportunities, converted at close
        SUM(amount_usd_at_close) FILTER (WHERE is_closed = TRUE AND is_won = TRUE) AS closed_won_usd

    FROM opportunities
    GROUP BY
        channel,
        opportunity_type
)

SELECT
    channel,
    opportunity_type,
    total_opportunities,
    closed_opportunities,
    won_opportunities,
    lost_opportunities,
    -- Won / (Won + Lost), excluding open opportunities
    ROUND((won_opportunities/NULLIF(closed_opportunities, 0))*100, 2) AS win_rate_pct,
    COALESCE(closed_won_usd, 0) AS closed_won_usd

FROM channel_performance
