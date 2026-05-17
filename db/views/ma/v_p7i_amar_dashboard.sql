-- ============================================================
-- OSA / ISA — P7I-AMAR Dashboard
-- Production merge pack v2
-- Public-safe operational view for AMAR domain.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7i_amar_dashboard AS
SELECT
    a.country_iso3,
    a.year,
    'ATROCITY_PRECURSOR'::varchar(50) AS risk_code,
    a.risk_band,
    a.risk_rank,
    a.atrocity_precursor_score AS risk_score,
    a.confidence_score,
    a.confidence_class,
    a.risk_interpretation,

    a.nb_pillars_monitored,
    a.structural_fragility_score,
    a.conflict_escalation_score,
    a.governance_breakdown_score,
    a.humanitarian_stress_score,
    a.resource_conflict_score,
    a.information_polarization_score,
    a.avg_abs_isa_trend_slope,
    a.avg_isa_volatility,
    a.avg_stress_delta,

    cy.country_early_warning_score,
    cy.country_early_warning_confidence,
    cy.country_sovereign_alert_level,
    cy.country_early_warning_status,

    CASE
        WHEN a.risk_band = 'BLACK' THEN 'URGENT_CIVILIAN_PROTECTION_REVIEW'
        WHEN a.risk_band = 'RED' THEN 'PREVENTION_ACTION_REQUIRED'
        WHEN a.risk_band = 'ORANGE' THEN 'EARLY_WARNING_REVIEW_REQUIRED'
        WHEN a.risk_band = 'YELLOW' THEN 'MONITORING_REQUIRED'
        ELSE 'NORMAL_MONITORING'
    END AS recommended_action,

    CASE
        WHEN a.risk_band = 'BLACK'
            THEN 'Urgent civilian protection risk. Preventive review required. This is an early-warning signal, not a legal qualification.'
        WHEN a.risk_band = 'RED'
            THEN 'Critical prevention risk requiring institutional review. This is not a legal qualification.'
        WHEN a.risk_band = 'ORANGE'
            THEN 'Early-warning atrocity precursor risk requiring reinforced monitoring.'
        WHEN a.risk_band = 'YELLOW'
            THEN 'Watchlist civilian protection risk requiring regular monitoring.'
        ELSE
            'Low monitored civilian protection risk.'
    END AS public_narrative,

    CASE
        WHEN a.confidence_score < 0.40 THEN TRUE
        ELSE FALSE
    END AS confidence_review_required

FROM ma.v_p7i_amar_atrocity_precursor_engine a
LEFT JOIN ma.v_isa_early_warning_country_year cy
       ON cy.country_iso3 = a.country_iso3
      AND cy.year = a.year;
