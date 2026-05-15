/* P7I risk escalation: year-over-year alert/risk change */
CREATE OR REPLACE VIEW ma.v_isa_risk_escalation_engine AS
WITH lagged AS (
    SELECT
        e.*,
        LAG(e.early_warning_score) OVER (PARTITION BY e.country_iso3, e.pillar_code ORDER BY e.year) AS previous_warning_score,
        LAG(e.sovereign_alert_level) OVER (PARTITION BY e.country_iso3, e.pillar_code ORDER BY e.year) AS previous_alert_level,
        LAG(e.alert_rank) OVER (PARTITION BY e.country_iso3, e.pillar_code ORDER BY e.year) AS previous_alert_rank
    FROM ma.v_isa_early_warning_engine e
), scored AS (
    SELECT
        *,
        COALESCE(early_warning_score - previous_warning_score, 0)::NUMERIC AS risk_delta,
        COALESCE(alert_rank - previous_alert_rank, 0)::INT AS alert_rank_delta
    FROM lagged
)
SELECT
    s.country_iso3,
    s.year,
    s.pillar_code,
    s.sovereign_alert_level,
    COALESCE(s.previous_alert_level, 'NO_PREVIOUS_YEAR')::TEXT AS previous_alert_level,
    s.alert_rank,
    COALESCE(s.previous_alert_rank, 0)::INT AS previous_alert_rank,
    ROUND(s.early_warning_score, 3)::NUMERIC(6,3) AS early_warning_score,
    ROUND(COALESCE(s.previous_warning_score, s.early_warning_score), 3)::NUMERIC(6,3) AS previous_warning_score,
    ROUND(s.risk_delta, 3)::NUMERIC(6,3) AS risk_delta,
    s.alert_rank_delta,
    CASE
        WHEN s.alert_rank_delta >= 2 OR s.risk_delta >= 0.150 THEN 'RISK_SURGING'
        WHEN s.alert_rank_delta = 1 OR s.risk_delta >= 0.050 THEN 'RISK_ESCALATING'
        WHEN s.risk_delta <= -0.050 THEN 'RISK_DE_ESCALATING'
        ELSE 'RISK_STABLE'
    END::TEXT AS risk_escalation_class,
    ep.escalation_label::TEXT AS risk_escalation_label,
    ep.escalation_action::TEXT AS risk_escalation_action,
    CASE
        WHEN s.alert_rank_delta >= 2 THEN 'ALERT_LEVEL_JUMP'
        WHEN s.alert_rank_delta = 1 THEN 'ALERT_LEVEL_INCREASE'
        WHEN s.risk_delta >= 0.150 THEN 'RISK_SCORE_SURGE'
        WHEN s.risk_delta >= 0.050 THEN 'RISK_SCORE_INCREASE'
        WHEN s.risk_delta <= -0.050 THEN 'RISK_SCORE_DECREASE'
        ELSE 'NO_SIGNIFICANT_CHANGE'
    END::TEXT AS escalation_reason
FROM scored s
JOIN rf.isa_risk_escalation_policy ep
  ON (CASE
        WHEN s.alert_rank_delta >= 2 OR s.risk_delta >= 0.150 THEN 'RISK_SURGING'
        WHEN s.alert_rank_delta = 1 OR s.risk_delta >= 0.050 THEN 'RISK_ESCALATING'
        WHEN s.risk_delta <= -0.050 THEN 'RISK_DE_ESCALATING'
        ELSE 'RISK_STABLE'
      END) = ep.escalation_class;
