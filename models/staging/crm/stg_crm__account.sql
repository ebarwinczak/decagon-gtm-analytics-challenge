{{
    config(
        materialized='view'
    )
}}

WITH source AS (

    SELECT *
    FROM {{ ref('account') }}

)

SELECT
    account_id,
    account_name,
    segment,
    region,
    country,
    industry,
    employee_count,
    account_created_date

FROM source
