UPDATE ops.audit_findings
SET description = description || E'\n\n--- Mise a jour : analyse statistique complete (21 juin 2026) ---\nTrois angles d''analyse independants convergent vers le meme diagnostic. (1) CORR(strategic_risk_score, weakness_score) = 0.958 sur n=2700 (2020-2024) : strategic_risk_score est quasi-redondant avec weakness_score, ce n''est pas un signal independant. (2) CORR(strategic_risk_score, threat_score) = -0.005 : relation statistiquement nulle, threat_score porte une information orthogonale qui n''est presque jamais captee par GREATEST(). (3) Analyse distributionnelle sur l''ensemble du dataset (n=8100, tous pays/annees/piliers) : threat_score a une moyenne globale de 0.0089 (signal eparse, quasi-silencieux, max=1.000 mais rarement atteint), tandis que weakness_score varie fortement selon strategic_attention_class (0.156 en DIAGNOSTIC_MONITORING vs 0.922 en DIAGNOSTIC_ATTENTION_MODERATE, n=7045 et 1045 respectivement). Meme dans la classe ATTENTION_MODERATE, censee signaler les situations preoccupantes, threat_score reste a 0.028 en moyenne -- quasi inchangee par rapport au niveau de base (0.006). Conclusion : la marginalisation de threat_score n''est pas un artefact ponctuel du GREATEST(), elle est structurelle des l''amont -- le moteur SWOT P7F produit un threat_score eparse et de faible amplitude qui ne peut presque jamais rivaliser avec weakness_score/strategic_risk_score, quel que soit le mecanisme d''agregation choisi en aval. Le diagnostic depasse donc le simple choix de GREATEST() : threat_score, tel que calcule actuellement dans le moteur SWOT, est structurellement sous-dimensionne pour jouer son role differentiateur dans un score precurseur de conflit. Hypothese imputation/qualite des donnees ecartee empiriquement (proportions IMPUTED quasi identiques entre pays compares). Diagnostic juge suffisamment etabli et converge pour transmission au Conseil technique OSA.',
    raw_finding = raw_finding || jsonb_build_object(
        'statistical_analysis', jsonb_build_object(
            'analyzed_at', '2026-06-21',
            'correlation_n', 2700,
            'correlation_period', '2020-2024',
            'corr_strategic_weakness', 0.958,
            'corr_strategic_threat', -0.005,
            'corr_strategic_vulnerability', 0.280,
            'corr_threat_weakness', -0.148,
            'global_distribution_n', 8100,
            'threat_score_global_avg', 0.00887,
            'weakness_score_global_avg', 0.255,
            'strategic_risk_score_global_avg', 0.180,
            'by_strategic_attention_class', jsonb_build_object(
                'DIAGNOSTIC_MONITORING', jsonb_build_object('n', 7045, 'avg_weakness', 0.156, 'avg_threat', 0.00598, 'avg_strategic_risk', 0.134),
                'DIAGNOSTIC_ATTENTION_MODERATE', jsonb_build_object('n', 1045, 'avg_weakness', 0.922, 'avg_threat', 0.0279, 'avg_strategic_risk', 0.484),
                'DIAGNOSTIC_UPSIDE_HIGH', jsonb_build_object('n', 10, 'avg_weakness', 0.565, 'avg_threat', 0.0538, 'avg_strategic_risk', 0.332)
            ),
            'imputation_hypothesis', jsonb_build_object(
                'tested', true,
                'cod_imputed_pct', 9.9,
                'cpv_imputed_pct', 10.6,
                'conclusion', 'Ecartee -- proportions quasi identiques entre pays en conflit et pays stable'
            ),
            'conclusion', 'threat_score structurellement marginalise en amont du moteur SWOT P7F, pas seulement victime du mecanisme GREATEST() en aval. Convergence de 3 angles d''analyse independants : dominance empirique, correlation, distribution.'
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, status, updated_at, jsonb_pretty(raw_finding->'statistical_analysis') AS stats_check;
