-- ============================================================
-- OSA / ISA — P7I-AMAR-GENECO Alert Refresh
-- Optional: persists GENECO alerts into mg.early_warning_alerts if table exists.
-- ============================================================

BEGIN;

DO $$
BEGIN
    IF to_regclass('mg.early_warning_alerts') IS NOT NULL THEN
        INSERT INTO mg.early_warning_alerts (
            country_iso3,
            year,
            risk_code,
            risk_band,
            risk_score,
            confidence_score,
            source_engine,
            public_narrative,
            created_at,
            updated_at
        )
        SELECT
            country_iso3,
            year,
            risk_code,
            risk_band,
            risk_score,
            confidence_score,
            'P7I-AMAR-GENECO' AS source_engine,
            CASE
                WHEN risk_band = 'BLACK' THEN 'Urgent conflict-economy exposure review required. This is not legal attribution.'
                WHEN risk_band = 'RED' THEN 'High conflict-economy exposure. Prevention and due-diligence review recommended.'
                WHEN risk_band = 'ORANGE' THEN 'Elevated conflict-economy exposure. Reinforced monitoring recommended.'
                WHEN risk_band = 'YELLOW' THEN 'Watchlist conflict-economy exposure. Regular monitoring recommended.'
                WHEN risk_band = 'LOW_CONFIDENCE' THEN 'Contextual conflict-economy signal. Expert review required due to low confidence.'
                ELSE 'Low monitored conflict-economy exposure.'
            END AS public_narrative,
            NOW(),
            NOW()
        FROM ma.v_p7i_amar_geneco_dashboard
        ON CONFLICT (country_iso3, year, risk_code, source_engine)
        DO UPDATE SET
            risk_band = EXCLUDED.risk_band,
            risk_score = EXCLUDED.risk_score,
            confidence_score = EXCLUDED.confidence_score,
            public_narrative = EXCLUDED.public_narrative,
            updated_at = NOW();
    ELSE
        RAISE NOTICE 'mg.early_warning_alerts does not exist. Skipping persisted alert refresh.';
    END IF;
END $$;

COMMIT;
