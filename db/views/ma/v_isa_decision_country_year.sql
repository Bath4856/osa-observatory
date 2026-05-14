CREATE OR REPLACE VIEW ma.v_isa_decision_country_year AS
WITH ranked AS (
 SELECT d.*, ROW_NUMBER() OVER(PARTITION BY country_iso3, year ORDER BY decision_priority_score DESC, decision_confidence_score DESC) rn
 FROM ma.v_isa_decision_priority_engine d
), agg AS (
 SELECT country_iso3, year,
        COUNT(*)::INTEGER nb_decision_items,
        COUNT(DISTINCT pillar_code)::INTEGER nb_pillars_with_decisions,
        SUM(CASE WHEN decision_priority_class='DECISION_CRITICAL' THEN 1 ELSE 0 END)::INTEGER nb_critical_decisions,
        SUM(CASE WHEN decision_priority_class='DECISION_HIGH' THEN 1 ELSE 0 END)::INTEGER nb_high_decisions,
        SUM(CASE WHEN decision_priority_class='DECISION_STANDARD' THEN 1 ELSE 0 END)::INTEGER nb_standard_decisions,
        SUM(CASE WHEN decision_priority_class='DECISION_MONITOR' THEN 1 ELSE 0 END)::INTEGER nb_monitor_decisions,
        AVG(decision_priority_score)::NUMERIC avg_decision_priority_score,
        MAX(decision_priority_score)::NUMERIC country_max_decision_priority_score,
        AVG(CASE WHEN rn<=3 THEN decision_priority_score END)::NUMERIC top3_decision_priority_score,
        AVG(decision_confidence_score)::NUMERIC country_decision_confidence_score,
        AVG(central_isa_delta)::NUMERIC avg_central_isa_delta,
        AVG(ambitious_isa_delta)::NUMERIC avg_ambitious_isa_delta,
        AVG(stress_isa_delta)::NUMERIC avg_stress_isa_delta
 FROM ranked GROUP BY country_iso3, year
), scored AS (
 SELECT *,
        CASE WHEN nb_decision_items=0 THEN 0::NUMERIC ELSE nb_critical_decisions::NUMERIC/nb_decision_items::NUMERIC END critical_ratio,
        LEAST(1.0,GREATEST(0.0,
          0.45*COALESCE(country_max_decision_priority_score,0)
          +0.30*COALESCE(top3_decision_priority_score,0)
          +0.15*CASE WHEN nb_decision_items=0 THEN 0 ELSE nb_critical_decisions::NUMERIC/nb_decision_items::NUMERIC END
          +0.10*COALESCE(country_decision_confidence_score,0)
        ))::NUMERIC country_decision_priority_score
 FROM agg
)
SELECT country_iso3, year, nb_decision_items, nb_pillars_with_decisions, nb_critical_decisions, nb_high_decisions,
       nb_standard_decisions, nb_monitor_decisions,
       ROUND(country_decision_priority_score,3) country_decision_priority_score,
       ROUND(country_max_decision_priority_score,3) country_max_decision_priority_score,
       ROUND(country_decision_confidence_score,3) country_decision_confidence_score,
       ROUND(avg_central_isa_delta,3) avg_central_isa_delta,
       ROUND(avg_ambitious_isa_delta,3) avg_ambitious_isa_delta,
       ROUND(avg_stress_isa_delta,3) avg_stress_isa_delta,
       CASE WHEN country_decision_priority_score>=0.820 OR (nb_critical_decisions>=3 AND country_max_decision_priority_score>=0.880) THEN 'COUNTRY_DECISION_CRITICAL'
            WHEN country_decision_priority_score>=0.650 OR nb_critical_decisions>=1 OR nb_high_decisions>=5 THEN 'COUNTRY_DECISION_HIGH'
            WHEN country_decision_priority_score>=0.450 OR nb_high_decisions>=1 THEN 'COUNTRY_DECISION_STANDARD'
            ELSE 'COUNTRY_DECISION_MONITOR' END AS country_decision_class,
       CASE WHEN country_decision_priority_score>=0.820 OR (nb_critical_decisions>=3 AND country_max_decision_priority_score>=0.880) THEN 'COUNTRY_DECISION_BOARD_REVIEW_REQUIRED'
            WHEN country_decision_priority_score>=0.650 OR nb_critical_decisions>=1 OR nb_high_decisions>=5 THEN 'COUNTRY_HIGH_PRIORITY_POLICY_REVIEW'
            WHEN country_decision_priority_score>=0.450 OR nb_high_decisions>=1 THEN 'COUNTRY_DECISION_READY'
            ELSE 'COUNTRY_MONITORING_ONLY' END AS country_decision_status
FROM scored;
