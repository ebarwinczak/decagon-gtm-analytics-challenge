SELECT
    opportunity_id,
    currency,
    is_closed,
    amount_usd_at_close,
    amount_usd_latest_date
FROM {{ ref('int_opportunities_enriched') }}
WHERE
    -- Every opportunity needs a latest-date USD valuation
    amount_usd_latest_date IS NULL

    -- Closed opportunities need a historical USD valuation
    OR (
        is_closed = TRUE
        AND amount_usd_at_close IS NULL
    )

    -- Open opportunities should not have a historical closing valuation
    OR (
        is_closed = FALSE
        AND amount_usd_at_close IS NOT NULL
    )
    