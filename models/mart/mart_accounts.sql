{{
    config(
        materialized='table'
    )
}}

-- Grain: one row per account
-- Reporting-ready account dataset

SELECT
    -- Account identifiers and attributes
    account_id,
    account_name,
    segment,
    account_region,
    country,
    industry,
    employee_count,
    account_created_date,
    -- Customer lifecycle
    account_status,
    is_customer,
    first_opportunity_created_date,
    first_won_date,
    first_new_business_won_date,
    first_pilot_created_date,
    has_won_pilot,
    has_won_expansion,
    -- Opportunity activity
    opportunity_count,
    won_opportunity_count,
    open_opportunity_count

FROM {{ ref('int_accounts_enriched') }}
