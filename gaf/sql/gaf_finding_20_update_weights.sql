UPDATE ops.audit_findings
SET description = description || E'\n\n--- Mise a jour : demonstration arithmetique ponderation theorique vs effective (21 juin 2026) ---\nFormule officielle de strategic_risk_score dans ma.v_isa_strategic_diagnostic_engine : ROUND(GREATEST(0, LEAST(1, weakness_score * 0.45 + threat_score * 0.35 + vulnerability_observed_score * 0.20)), 3). Ponderation theorique : weakness 45%, threat 35%, vulnerability 20%. Appliquee aux moyennes observees sur ma.computed_values (tous pays, toutes annees) : weakness_avg ≈ 0.77, threat_avg ≈ 0.03, vulnerability_avg ≈ 0.25 (ordre de grandeur). Contributions moyennes effectives : weakness 0.77 x 0.45 = 0.347, threat 0.03 x 0.35 = 0.011, vulnerability 0.25 x 0.20 = 0.050. Part relative effective : weakness 85%, threat 3%, vulnerability 12%. Le probleme n''est pas dans les ponderations. Le probleme est dans les echelles. Le moteur applique 45/35/20 theoriquement mais produit 85/3/12 effectivement. C''est un cas classique de ponderation theorique != ponderation effective, cause par l''incompatibilite d''echelle entre WKN (mesure de niveau, calibre 0.5-1.0) et THR (mesure de changement/volatilite, calibre 0.01-0.07). La formule croit donner a la trajectoire (THR) un poids de 35% ; elle lui donne reellement 3%. Ce constat est la formulation la plus precise et la plus directement actionale du probleme pour arbitrage par le Conseil technique OSA : toute correction devra adresser la calibration des echelles WKN/THR en amont plutot que les ponderations de la formule en aval.',
    raw_finding = raw_finding || jsonb_build_object(
        'effective_weighting_analysis', jsonb_build_object(
            'analyzed_at', '2026-06-21',
            'formula', 'weakness * 0.45 + threat * 0.35 + vulnerability * 0.20',
            'theoretical_weights', jsonb_build_object('weakness', 0.45, 'threat', 0.35, 'vulnerability', 0.20),
            'observed_means', jsonb_build_object('weakness', 0.77, 'threat', 0.03, 'vulnerability', 0.25),
            'effective_contributions', jsonb_build_object('weakness', 0.347, 'threat', 0.011, 'vulnerability', 0.050),
            'effective_weights', jsonb_build_object('weakness', 0.85, 'threat', 0.03, 'vulnerability', 0.12),
            'strategic_risk_avg_implied', 0.408,
            'key_finding', 'Ponderation theorique 45/35/20 -- ponderation effective 85/3/12. Ecart cause par incompatibilite d''echelle WKN (niveau, 0.5-1.0) vs THR (changement, 0.01-0.07), pas par un defaut de la formule.',
            'correction_target', 'Calibration des echelles WKN/THR en amont (ma.computed_values), pas les ponderations de la formule'
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, status, updated_at;
