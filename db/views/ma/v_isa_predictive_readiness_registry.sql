CREATE OR REPLACE VIEW ma.v_isa_predictive_readiness_registry AS
SELECT
    pillar_code,
    COUNT(*)                                                AS nb_rows,
    ROUND(AVG(executive_priority_score)::NUMERIC,   3)     AS avg_priority,
    ROUND(AVG(systemic_cascade_score)::NUMERIC,     3)     AS avg_cascade,
    ROUND(AVG(sovereign_execution_pressure)::NUMERIC, 3)   AS avg_pressure,
    -- predictive_gap_score : distance au seuil EXEC_READY_CAUTION
    ROUND(AVG(predictive_gap_score)::NUMERIC,       3)     AS avg_predictive_gap,
    ROUND(MIN(predictive_gap_score)::NUMERIC,       3)     AS min_predictive_gap,
    -- nb_predictive_ready : EXEC_READY uniquement (VALIDATED)
    SUM(CASE WHEN predictive_ready_flag = TRUE
        THEN 1 ELSE 0 END)                                  AS nb_predictive_ready,
    -- nb_predictive_caution : EXEC_READY_CAUTION (PROVISIONAL)
    SUM(CASE WHEN predictive_execution_status = 'EXEC_READY_CAUTION'
        THEN 1 ELSE 0 END)                                  AS nb_predictive_caution,
    -- nb_predictive_blocked : EXEC_BLOCKED_REVIEW
    SUM(CASE WHEN predictive_execution_status = 'EXEC_BLOCKED_REVIEW'
        THEN 1 ELSE 0 END)                                  AS nb_predictive_blocked
FROM ma.v_isa_executive_master_board
GROUP BY pillar_code
ORDER BY avg_predictive_gap ASC;
