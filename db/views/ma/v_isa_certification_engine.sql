-- ============================================================
-- OSA / ISA — P8A View: ma.v_isa_certification_engine
-- Source: ma.v_isa_observed_scores_by_country_year
-- Uses only confirmed P7E columns.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_certification_engine AS
WITH base AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INTEGER AS year,
        COALESCE(publication_status, 'EXCLUDED_NOT_READY')::TEXT AS publication_status,
        COALESCE(publication_decision, 'DO_NOT_PUBLISH')::TEXT AS publication_decision,
        COALESCE(nb_pillars_observed, 0)::INTEGER AS nb_pillars_observed,
        COALESCE(data_completeness, 0)::NUMERIC AS data_completeness,
        COALESCE(isa_observed_score, 0)::NUMERIC AS isa_observed_score,
        COALESCE(sovereignty_observed_score, 0)::NUMERIC AS sovereignty_observed_score,
        COALESCE(vulnerability_observed_score, 0)::NUMERIC AS vulnerability_observed_score
    FROM ma.v_isa_observed_scores_by_country_year
),
scored AS (
    SELECT
        b.*,
        ROUND(LEAST(1.000, GREATEST(0.000,
              b.data_completeness * 0.55
            + LEAST(b.nb_pillars_observed::NUMERIC / 10.0, 1.0) * 0.35
            + CASE
                WHEN b.publication_status = 'OFFICIAL_CONSOLIDATED' THEN 0.10
                WHEN b.publication_status = 'PROVISIONAL_N1' THEN 0.05
                ELSE 0.00
              END
        )), 3) AS certification_confidence_proxy,
        CASE
            WHEN b.publication_status = 'OFFICIAL_CONSOLIDATED'
             AND b.data_completeness >= 0.850
             AND b.nb_pillars_observed >= 8
                THEN 'CERTIFIED'
            WHEN b.publication_status = 'PROVISIONAL_N1'
             AND b.data_completeness >= 0.650
             AND b.nb_pillars_observed >= 7
                THEN 'PROVISIONAL'
            WHEN b.data_completeness < 0.450
              OR b.nb_pillars_observed < 5
                THEN 'REJECTED'
            ELSE 'REVIEW_REQUIRED'
        END AS certification_status
    FROM base b
)
SELECT
    s.*,
    p.policy_code,
    p.allows_open_data,
    p.allows_premium_delivery,
    p.freeze_eligible,
    p.certification_note,
    CASE
        WHEN s.certification_status = 'CERTIFIED' THEN 'CERTIFICATION_READY'
        WHEN s.certification_status = 'PROVISIONAL' THEN 'CERTIFICATION_PROVISIONAL'
        WHEN s.certification_status = 'REVIEW_REQUIRED' THEN 'CERTIFICATION_REVIEW_REQUIRED'
        ELSE 'CERTIFICATION_REJECTED'
    END AS certification_readiness_status,
    MD5(CONCAT_WS('|',
        s.country_iso3, s.year, s.publication_status, s.certification_status,
        s.isa_observed_score, s.sovereignty_observed_score,
        s.vulnerability_observed_score,
        s.certification_confidence_proxy
    )) AS certification_audit_hash
FROM scored s
LEFT JOIN rf.isa_certification_policy p
    ON p.certification_status = s.certification_status;
