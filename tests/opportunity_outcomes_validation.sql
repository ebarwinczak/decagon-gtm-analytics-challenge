-- Test that opportunity stage and outcome flags are consistent.
-- A dbt singular test passes when the query returns zero rows.

SELECT
    opportunity_id,
    stage,
    is_closed,
    is_won
FROM {{ ref('opportunity') }}
WHERE
    -- Closed Won must be closed and won
    (
        stage = 'Closed Won'
        AND (
            is_closed IS DISTINCT FROM TRUE
            OR is_won IS DISTINCT FROM TRUE
        )
    )

    OR

    -- Closed Lost must be closed but not won
    (
        stage = 'Closed Lost'
        AND (
            is_closed IS DISTINCT FROM TRUE
            OR is_won IS DISTINCT FROM FALSE
        )
    )

    OR

    -- All other recognized stages must be open and not won
    (
        stage IN (
            'Discovery',
            'Scoping',
            'Technical Validation',
            'Pilot',
            'Proposal',
            'Negotiation'
        )
        AND (
            is_closed IS DISTINCT FROM FALSE
            OR is_won IS DISTINCT FROM FALSE
        )
    )

    OR

    -- Flag missing or unexpected stage values
    (
        stage IS NULL
        OR stage NOT IN (
            'Closed Won',
            'Closed Lost',
            'Discovery',
            'Scoping',
            'Technical Validation',
            'Pilot',
            'Proposal',
            'Negotiation'
        )
    )