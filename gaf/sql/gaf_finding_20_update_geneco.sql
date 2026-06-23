UPDATE ops.audit_findings
SET module = 'P7I-AMAR / P7I-AMAR-GENECO',
    finding_code = 'STRATEGIC_RISK_SIGNAL_DOMINANCE_GREATEST',
    description = description || E'\n\n--- Mise a jour : verification GENECO (21 juin 2026) ---\nLe moteur GENECO (ma.v_p7i_amar_geneco_engine, ligne risk_component) utilise EXACTEMENT le meme mecanisme GREATEST() sur la meme vue source ma.v_p7i_risk_source, avec un 4e terme abs(stress_isa_delta) en plus de threat_score/strategic_risk_score/vulnerability_observed_score. Verification empirique sur COD vs CPV 2024 avec les 4 termes : resultat identique a AMAR -- strategic_risk_score domine 8/10 piliers pour COD et 7/10 pour CPV, le terme abs(stress_isa_delta) ne gagne jamais (valeurs 0.016-0.070, trop petites face a strategic_risk_score ~0.2-0.5). Le mecanisme de compression n''est donc pas specifique a AMAR : il est partage par construction entre les deux modules via la vue source commune. Distinct de mg.geneco_underclassification_watch (11 cas Sprint-5, mecanisme different : sous-poids du composant logistics_enabling_risk/PTRA sur des cas individuels, pas une dominance systemique de GREATEST()).',
    raw_finding = raw_finding || jsonb_build_object(
        'geneco_verification', jsonb_build_object(
            'verified_at', '2026-06-21',
            'source_view', 'ma.v_p7i_amar_geneco_engine',
            'mechanism', 'GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score, abs(stress_isa_delta))',
            'cod_pillar_dominance_4term', jsonb_build_object(
                'strategic_risk_wins', 8, 'threat_wins', 1, 'vulnerability_wins', 1, 'stress_delta_wins', 0, 'total_pillars', 10
            ),
            'cpv_pillar_dominance_4term', jsonb_build_object(
                'strategic_risk_wins', 7, 'threat_wins', 0, 'vulnerability_wins', 3, 'stress_delta_wins', 0, 'total_pillars', 10
            ),
            'conclusion', 'Meme mecanisme de compression que AMAR, confirme empiriquement. Distinct de mg.geneco_underclassification_watch (11 cas geres separement depuis Sprint-5).'
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, module, status, updated_at;
