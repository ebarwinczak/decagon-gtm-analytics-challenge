{{
    config(
        materialized='view'
    )
}}

WITH accounts AS (
    SELECT
        account_id,
        account_name,
        segment,
        region AS account_region,
        country,
        industry,
        employee_count,
        account_created_date

    FROM {{ ref('stg_crm__account') }}
),

account_history AS (
    SELECT
        account_id,
        first_opportunity_created_date,
        first_won_date,
        first_new_business_won_date,
        first_pilot_created_date,
        is_customer,
        has_won_pilot,
        has_won_expansion,
        account_status,
        opportunity_count,
        won_opportunity_count,
        open_opportunity_count
        
    FROM {{ ref('int_accounts__customer_history') }}
)

SELECT
    -- Account identifiers and attributes
    acc.account_id,
    acc.account_name,
    acc.segment,
    acc.account_region,
    acc.country,
    acc.industry,
    acc.employee_count,
    acc.account_created_date,
    -- Customer lifecycle
    acc_hist.account_status,
    acc_hist.is_customer,
    acc_hist.first_opportunity_created_date,
    acc_hist.first_won_date,
    acc_hist.first_new_business_won_date,
    acc_hist.first_pilot_created_date,
    acc_hist.has_won_pilot,
    acc_hist.has_won_expansion,
    -- Opportunity activity
    acc_hist.opportunity_count,
    acc_hist.won_opportunity_count,
    acc_hist.open_opportunity_count

FROM accounts AS acc

LEFT JOIN account_history AS acc_hist
    ON acc.account_id = acc_hist.account_id