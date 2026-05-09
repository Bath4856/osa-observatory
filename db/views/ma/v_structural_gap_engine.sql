CREATE OR REPLACE VIEW ma.v_structural_gap_engine AS
SELECT
    country_iso3, year, pillar_code,
    COUNT(*) AS nb_signals,
    ROUND(AVG(signal_trust_score)::NUMERIC,3) AS avg_trust_score,
    ROUND(AVG(signal_vulnerability_score)::NUMERIC,3) AS avg_vulnerability_score,
    ROUND(AVG(coverage_score)::NUMERIC,3) AS avg_coverage_score,
    ROUND(AVG(mapping_quality_score)::NUMERIC,3) AS avg_mapping_quality_score,
    ROUND(AVG(mapping_maturity_score)::NUMERIC,3) AS avg_mapping_maturity_score,
    SUM(CASE WHEN signal_status='STRUCTURAL_GAP' THEN 1 ELSE 0 END) AS nb_structural_gaps,
    SUM(CASE WHEN signal_status='NATURE_GAP' THEN 1 ELSE 0 END) AS nb_nature_gaps,
    SUM(CASE WHEN vulnerability_reason='PHYSICAL_ESTIMATION_RISK' THEN 1 ELSE 0 END) AS nb_physical_estimation_risks,
    SUM(CASE WHEN vulnerability_reason='LOW_COVERAGE' THEN 1 ELSE 0 END) AS nb_low_coverage_signals,
    SUM(CASE WHEN is_estimated THEN 1 ELSE 0 END) AS nb_estimated_signals,
    ROUND(LEAST(1, (
        AVG(signal_vulnerability_score)
        + 0.05 * SUM(CASE WHEN signal_status='STRUCTURAL_GAP' THEN 1 ELSE 0 END)
        + 0.03 * SUM(CASE WHEN signal_status='NATURE_GAP' THEN 1 ELSE 0 END)
        + 0.04 * SUM(CASE WHEN vulnerability_reason='PHYSICAL_ESTIMATION_RISK' THEN 1 ELSE 0 END)
    ))::NUMERIC,3) AS structural_gap_score,
    CASE
        WHEN LEAST(1, AVG(signal_vulnerability_score)
            + 0.05 * SUM(CASE WHEN signal_status='STRUCTURAL_GAP' THEN 1 ELSE 0 END)
            + 0.03 * SUM(CASE WHEN signal_status='NATURE_GAP' THEN 1 ELSE 0 END)
            + 0.04 * SUM(CASE WHEN vulnerability_reason='PHYSICAL_ESTIMATION_RISK' THEN 1 ELSE 0 END)
        ) >= 0.75 THEN 'CRITICAL_STRUCTURAL_GAP'
        WHEN AVG(signal_vulnerability_score) >= 0.55 THEN 'HIGH_STRUCTURAL_GAP'
        WHEN AVG(signal_vulnerability_score) >= 0.40 THEN 'MODERATE_STRUCTURAL_GAP'
        ELSE 'CONTROLLED_SIGNAL'
    END AS structural_gap_class
FROM ma.v_signal_trust_engine
GROUP BY country_iso3, year, pillar_code;
