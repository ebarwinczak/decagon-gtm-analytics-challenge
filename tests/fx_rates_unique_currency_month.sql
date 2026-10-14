-- testing that the combination of month and FX currencey cols are unique
SELECT
    currency,
    rate_month,
    COUNT(*) AS row_count
FROM {{ ref('fx_rates_monthly') }}
GROUP BY
    currency,
    rate_month
HAVING COUNT(*) > 1
