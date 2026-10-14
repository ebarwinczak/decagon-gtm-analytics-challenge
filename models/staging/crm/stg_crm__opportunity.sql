{{
    config(
        materialized='view'
    )
}}

WITH source AS (

    SELECT *
    FROM {{ ref('opportunity') }}

)

SELECT
    -- Opportunity identifiers
    opportunity_id,
    account_id,
    opportunity_name,
    -- Sales ownership
    owner_id,
    owner_name,
    owner_role,
    owner_region,
    -- Opportunity classification
    opportunity_type,
    lead_source,
    NULLIF(TRIM(campaign), '') AS campaign, -- normalize blank strings
    -- Financial attributes
    CAST(amount AS DECIMAL(18,2)) AS amount_local, -- more appropriate for financial reporting; rename ammount_local since its the original currency field
    currency,
    -- Sales process
    stage,
    forecast_category,
    probability AS probability_pct, -- this is a 0-100 integer (not a decimal), so making that explicit in its name
    -- Dates
    created_date,
    close_date,
    last_activity_date,
    scoping_entered_date,
    -- Outcome flags
    is_closed,
    is_won,
    -- Loss information
    NULLIF(TRIM(loss_reason), '') AS loss_reason -- normalize blank string values 

FROM source
