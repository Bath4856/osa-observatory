UPDATE ops.audit_findings
SET
    description = description || E'\n\n--- Decision Conseil technique OSA : AMAR Trigger Engine independant (22 juin 2026) ---\nOption retenue : Trigger independant (court-circuit). Le Strategic Risk Score reste inchange -- l''historique est conserve et la logique de diagnostic continue de fonctionner sans modification. Creation d''un AMAR Trigger Engine independant : IF THR >= seuil THEN Trigger = TRUE. Un pays peut desormais etre simultanement MONITORING (Strategic Risk Score normal) ET THR Trigger ACTIVE (signal exceptionnel independant). Exemple concret : SDN 2024 -- Strategic Risk = 0.376 / MONITORING, ET THR Trigger = ACTIVE (threat_score PENV = 1.000). Ce qui etait un signal invisible dans le score scalaire devient une alerte explicite sans alterer le score. Separation doctrinale actee : Strategic Risk = diagnostic structurel continu / THR Trigger = evenement exceptionnel d''alerte. Cette decision resout la reserve de mise en oeuvre de la Regle 4 (architecture de court-circuit). Point ouvert restant avant implementation : definition du seuil THR et de la logique de declenchement -- seuil sur un seul pilier (plus sensible) ou sur une combinaison de piliers (plus robuste). Les donnees disponibles permettent une simulation empirique des deux options (18 lignes threat_score > 0.20 sur 8100 = 0.2% au niveau country x pillar x year). A trancher par le Conseil technique avant developpement.',
    raw_finding = raw_finding || jsonb_build_object(
        'trigger_engine_decision', jsonb_build_object(
            'decided_at', '2026-06-22',
            'decided_by', 'Conseil technique OSA',
            'option_chosen', 'Trigger independant (court-circuit)',
            'strategic_risk_score', 'INCHANGE -- historique conserve',
            'new_component', 'AMAR Trigger Engine -- IF THR >= seuil THEN Trigger = TRUE',
            'dual_state_example', jsonb_build_object(
                'country', 'SDN',
                'year', 2024,
                'strategic_risk_score', 0.376,
                'amar_class', 'MONITORING',
                'thr_trigger', 'ACTIVE',
                'threat_score_penv', 1.000
            ),
            'doctrinal_separation', jsonb_build_object(
                'strategic_risk', 'Diagnostic structurel continu',
                'thr_trigger', 'Evenement exceptionnel d''alerte'
            ),
            'swot', jsonb_build_object(
                'forces', jsonb_build_array('coherence doctrinale forte', 'conservation historique', 'separation claire Diagnostic vs Alerte'),
                'faiblesses', jsonb_build_array('nouvelle logique a documenter'),
                'opportunites', jsonb_build_array('veritable identite AMAR'),
                'menaces', jsonb_build_array('necessite audit annuel des triggers')
            ),
            'open_point', jsonb_build_object(
                'question', 'Seuil THR et logique de declenchement : un seul pilier ou combinaison de piliers ?',
                'data_available', '18 lignes threat_score > 0.20 sur 8100 (0.2%) au niveau country x pillar x year',
                'simulation_possible', true,
                'blocking', 'Implementation AMAR Trigger Engine'
            )
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, status, updated_at;

UPDATE ops.audit_findings
SET
    description = description || E'\n\n--- Mise a jour : architecture Trigger Engine definie pour AMAR (22 juin 2026) ---\nLa decision Conseil technique du 22 juin 2026 (finding_id=20) definit l''architecture du THR Trigger Audit pour AMAR : Trigger Engine independant, IF THR >= seuil THEN Trigger = TRUE, Strategic Risk Score inchange. Pour GENECO : l''architecture Trigger Engine AMAR s''applique par deduction si GENECO reste un moteur derive de P7I (decision finding_id=22 GENECO_OBSERVATIONAL_DOCTRINE_ALIGNMENT). Si GENECO evolue vers un moteur autonome (GENECO v2/v3), le Trigger Engine GENECO sera a concevoir independamment. Ce finding reste OPEN en attente de la decision d''evolution de GENECO (finding_id=22).',
    raw_finding = raw_finding || jsonb_build_object(
        'amar_trigger_architecture_reference', jsonb_build_object(
            'finding_id', 20,
            'decision', 'Trigger Engine independant -- IF THR >= seuil THEN Trigger = TRUE',
            'applicability_to_geneco', 'Par deduction si GENECO reste derive de P7I -- a re-concevoir si GENECO v2/v3 autonome',
            'blocking_condition', 'Evolution GENECO vers moteur autonome (finding_id=22)'
        )
    ),
    updated_at = now()
WHERE finding_id = 21
RETURNING finding_id, status, updated_at;
