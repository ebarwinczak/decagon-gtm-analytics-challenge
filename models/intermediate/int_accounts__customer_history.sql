{{
    config(
        materialized='table'
    )
}}

WITH accounts AS (
    SELECT *
    FROM {{ ref('stg_crm__account') }}
),

opportunities AS (
    SELECT *
    FROM {{ ref('stg_crm__opportunity') }}
),

opportunity_rollup AS (
    SELECT
        account_id,
        -- First opportunity created
        MIN(created_date) AS first_opportunity_created_date,
        -- First won opportunity, regardless of type
        MIN(close_date) FILTER (
            WHERE is_won = TRUE
        ) AS first_won_date,
        -- First won New Business opportunity (customer acquisition)
        MIN(close_date) FILTER (
            WHERE opportunity_type = 'New Business'
              AND is_won = TRUE
        ) AS first_new_business_won_date,
        -- First pilot created
        MIN(created_date) FILTER (
            WHERE opportunity_type = 'Pilot'
        ) AS first_pilot_created_date,
        -- Whether the account has won a pilot
        BOOL_OR(
            opportunity_type = 'Pilot' AND is_won
        ) AS has_won_pilot,
        -- Whether the account has won an expansion
        BOOL_OR(
            opportunity_type = 'Expansion' AND is_won
        ) AS has_won_expansion,
        -- Opportunity counts
        COUNT(*) AS opportunity_count,
        COUNT(*) FILTER (
            WHERE is_won
        ) AS won_opportunity_count,
        COUNT(*) FILTER (
            WHERE NOT is_closed
        ) AS open_opportunity_count

    FROM opportunities
    GROUP BY account_id
)

SELECT
    acc.account_id,
    -- Account lifecycle dates
    opp.first_opportunity_created_date,
    opp.first_won_date,
    opp.first_new_business_won_date,
    opp.first_pilot_created_date,
    -- Customer status: requires a won New Business opportunity
    (opp.first_new_business_won_date IS NOT NULL) AS is_customer,
    -- Pilot and expansion history
    COALESCE(opp.has_won_pilot, FALSE) AS has_won_pilot,
    COALESCE(opp.has_won_expansion, FALSE) AS has_won_expansion,
    -- Account lifecycle classification
    CASE
        WHEN opp.first_new_business_won_date IS NOT NULL
            THEN 'Customer'
        WHEN opp.open_opportunity_count > 0
            THEN 'In pipeline'
        WHEN opp.opportunity_count > 0
            THEN 'Engaged, not customer'
        ELSE 'Never engaged'
    END AS account_status,
    -- Opportunity counts
    COALESCE(opp.opportunity_count, 0) AS opportunity_count,
    COALESCE(opp.won_opportunity_count, 0) AS won_opportunity_count,
    COALESCE(opp.open_opportunity_count, 0) AS open_opportunity_count

FROM accounts AS acc 

LEFT JOIN opportunity_rollup AS opp
    ON acc.account_id = opp.account_id
