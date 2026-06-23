UPDATE ops.audit_findings
SET description = description || E'\n\n--- Mise a jour : cause racine fondamentale et lecture doctrinale (21 juin 2026) ---\nVerification sur l''ensemble du catalogue ma.computed_values (tous pays, toutes annees, 10 piliers) : les indicateurs WKN_* affichent des moyennes de 0.57 a 0.92 selon le pilier, sans exception. Les indicateurs THR_* affichent des moyennes de 0.015 a 0.068 selon le pilier, egalement sans exception. Ce ne sont pas deux signaux sur une echelle commune qui different selon les cas -- ce sont deux echelles structurellement incompatibles, l''une vivant systematiquement pres de 1, l''autre systematiquement pres de 0, pour tous les pays et toutes les annees. Examen du schema components (jsonb) confirme une difference de nature : WEAKNESS est une moyenne normalisee de niveau ({"nb_pos", "moy_norm", "indicateurs"}), tandis que THREAT mesure variation/volatilite/intensite ({"variation", "volatilite", "intensite"}) -- une mesure de changement, pas de niveau. Consequence : quelle que soit la methode d''agregation choisie en aval (GREATEST, moyenne ponderee ou autre), toute combinaison sera structurellement dominee par weakness tant que les deux echelles ne sont pas recalibrees sur une base comparable. GREATEST() ne fait qu''exposer un desequilibre deja present a la source.\n\nLecture doctrinale : ce desequilibre est une instanciation concrete, au niveau du module AMAR, du principe fondateur OSA selon lequel la souverainete doit etre analysee a la fois par la position et par la trajectoire. WKN (weakness/strategic_risk) est par construction une mesure de position (niveau structurel observe). THR (threat) etait concu comme une mesure de trajectoire (variation, volatilite, intensite du changement). Dans l''etat actuel du moteur AMAR, la position domine integralement le score precurseur tandis que la trajectoire reste quasi inaudible (moyenne globale 0.0089) -- soit l''exact inverse de l''equilibre position/trajectoire que la doctrine OSA prescrit. Ce constat fournit une explication unifiee et coherente a la dominance de weakness, la quasi-nullite de threat, et la faible discrimination du score AMAR/GENECO observee sur 2024 (52/54 pays en YELLOW). Diagnostic complet, convergent sur 4 angles independants (dominance empirique, correlation statistique, distribution par classe diagnostique, echelle de calibration source), et relie explicitement a la doctrine fondatrice OSA. Pret pour transmission et arbitrage par le Conseil technique OSA.',
    raw_finding = raw_finding || jsonb_build_object(
        'root_cause_analysis', jsonb_build_object(
            'analyzed_at', '2026-06-21',
            'source_table', 'ma.computed_values',
            'scope', 'tous pays, toutes annees 2020-2026, 10 piliers',
            'wkn_avg_by_pillar_range', jsonb_build_array(0.568, 0.924),
            'thr_avg_by_pillar_range', jsonb_build_array(0.0153, 0.0678),
            'wkn_components_schema', jsonb_build_object('type', 'niveau', 'fields', jsonb_build_array('nb_pos', 'moy_norm', 'indicateurs')),
            'thr_components_schema', jsonb_build_object('type', 'changement', 'fields', jsonb_build_array('variation', 'volatilite', 'intensite')),
            'conclusion', 'Echelles WKN/THR structurellement incompatibles a la source -- WKN pres de 1, THR pres de 0, systematiquement, independamment du pays ou de la situation reelle. GREATEST() expose ce desequilibre, ne le cree pas.'
        ),
        'doctrinal_reading', jsonb_build_object(
            'principle', 'Souverainete analysee a la fois par la position et par la trajectoire',
            'wkn_role', 'Position (niveau structurel observe)',
            'thr_role', 'Trajectoire (variation/volatilite/intensite du changement)',
            'observed_state', 'Position domine integralement, trajectoire quasi inaudible -- inverse de l''equilibre doctrinal prescrit',
            'noted_by', 'Theo, 21 juin 2026'
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, status, updated_at;
