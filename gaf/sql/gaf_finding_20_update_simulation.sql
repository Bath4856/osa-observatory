UPDATE ops.audit_findings
SET
    description = description || E'\n\n--- Simulation Trigger Engine : resultats empiriques 2020-2024 (22 juin 2026) ---\nSimulation appliquee sur ma.v_p7i_risk_source (n=2700, 2020-2024) avec la taxonomie a 4 classes validee par le Conseil technique. Resultats : TRIGGER_EXCEPTIONAL=2, TRIGGER_CRITICAL=3, TRIGGER_ACTIVE=13, TRIGGER_DIAGNOSTIC_INCOMPLETE=0. Total : 18 declenchements sur 5 ans (0,67% des lignes). Distribution annuelle : 2021=5 pays, 2022=6 pays, 2023=0 pays, 2024=7 pays. Piliers declencheurs : PMIN 10/18 (56%), PENV 6/18 (33%), PRES 1/18, PMON 1/18, PMIL=0, PHUM=0, PGEO=0. Trois observations pour le Conseil technique : (1) TRIGGER_DIAGNOSTIC_INCOMPLETE ne se declenche jamais empiriquement -- SDN PENV est absorbe par TRIGGER_EXCEPTIONAL (THR=1.000 >= 0.40) avant la verification WKN. La definition doit etre clarifiee : s''applique-t-elle uniquement sous le seuil EXCEPTIONAL, ou remplace-t-elle toute classification si WKN absent ? (2) TRIGGER_CRITICAL tres selectif (3 cas / 5 ans) -- ETH 2021 PENV, LSO 2022 PENV, ETH 2022 PMON -- volume de revue humaine annuel tres gerable. (3) Dominance PMIN (56%) : le Trigger Engine a seuil pilier-agnostique declenche majoritairement sur des tensions minieres, pas sur les piliers les plus pertinents pour un precurseur d''atrocites (PMIL, PHUM, PGEO = 0 declenchement sur 5 ans). Une ponderation pilier-specifique est envisageable en Sprint 2 du Trigger Engine. Anomalie WKN identifiee : SDN WKN_PENV = NULL (confidence=0.000 dans ma.computed_values 2024) et COD WKN_PENV = 0.051 (confidence=0.293, 7 MISSING sur PENV) -- weakness_score quasi nul par COALESCE(...,0) sur ces deux pays en 2024. A investiguer separement comme finding qualite donnees.',
    raw_finding = raw_finding || jsonb_build_object(
        'trigger_simulation', jsonb_build_object(
            'simulated_at', '2026-06-22',
            'source', 'ma.v_p7i_risk_source',
            'period', '2020-2024',
            'n_total', 2700,
            'taxonomy_applied', jsonb_build_object(
                'TRIGGER_EXCEPTIONAL', 'THR >= 0.40',
                'TRIGGER_CRITICAL', 'THR >= 0.20 AND WKN >= 0.70 AND conf_wkn > 0',
                'TRIGGER_ACTIVE', 'THR >= 0.20 (autres cas)',
                'TRIGGER_DIAGNOSTIC_INCOMPLETE', 'THR >= 0.20 AND (WKN absent ou conf = 0)'
            ),
            'results_summary', jsonb_build_object(
                'TRIGGER_EXCEPTIONAL', 2,
                'TRIGGER_CRITICAL', 3,
                'TRIGGER_ACTIVE', 13,
                'TRIGGER_DIAGNOSTIC_INCOMPLETE', 0,
                'total', 18,
                'pct_of_total', 0.67
            ),
            'by_year', jsonb_build_object(
                '2021', jsonb_build_object('pays', 5, 'pays_list', jsonb_build_array('COG','ETH','GHA','LBY','SLE')),
                '2022', jsonb_build_object('pays', 6, 'pays_list', jsonb_build_array('COG','ETH','GAB','LSO','MDG','SLE')),
                '2023', jsonb_build_object('pays', 0, 'note', 'Aucun declenchement -- dont absence SDN guerre civile avril 2023'),
                '2024', jsonb_build_object('pays', 7, 'pays_list', jsonb_build_array('CMR','COD','LBR','NAM','RWA','SDN','ZMB'))
            ),
            'pillar_distribution', jsonb_build_object(
                'PMIN', jsonb_build_object('count', 10, 'pct', 56),
                'PENV', jsonb_build_object('count', 6, 'pct', 33),
                'PRES', jsonb_build_object('count', 1, 'pct', 6),
                'PMON', jsonb_build_object('count', 1, 'pct', 6),
                'PMIL', jsonb_build_object('count', 0, 'pct', 0),
                'PHUM', jsonb_build_object('count', 0, 'pct', 0),
                'PGEO', jsonb_build_object('count', 0, 'pct', 0)
            ),
            'open_points', jsonb_build_array(
                'TRIGGER_DIAGNOSTIC_INCOMPLETE : clarifier si applicable sous EXCEPTIONAL seulement ou prioritaire sur toute classification',
                'Dominance PMIN (56%) : envisager ponderation pilier-specifique en Sprint 2 Trigger Engine',
                'Absence 2023 : verifier donnees THR 2023 pour SDN -- guerre civile avril 2023 non capturee',
                'Anomalie WKN : SDN WKN_PENV=NULL et COD WKN_PENV=0.051/conf=0.293 -- a investiguer qualite donnees'
            )
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, status, updated_at;
