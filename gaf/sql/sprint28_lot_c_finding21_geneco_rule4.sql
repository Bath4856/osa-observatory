-- ============================================================
-- Sprint 28 Lot C -- Resolution finding #21
-- GENECO_ANALYTICAL_INDEPENDENCE : OPEN -> ORIENTED
-- Rule 4 GENECO actee par le Conseil technique OSA
-- 25 juin 2026
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint28_lot_c_finding21_geneco_rule4.sql
-- ============================================================

BEGIN;

UPDATE ops.audit_findings
SET
    status      = 'ORIENTED',
    description = description
        || E'\n\n--- Resolution finding #21 : Conseil technique OSA (25 juin 2026) ---\n'
        || E'\nDecision : Option B modifiee -- Rule 4 GENECO autonome, sans THR.\n'
        || E'\nFondement doctrinal :\n'
        || E'THR est un concept herite d''AMAR -- il mesure l''intensite d''un changement\n'
        || E'soudain (rupture ponctuelle). GENECO observe des mecanismes, c''est-a-dire\n'
        || E'des configurations qui s''installent et se maintiennent dans le temps.\n'
        || E'Un mecanisme de fragilisation souveraine n''a pas de seuil de declenchement.\n'
        || E'Il a une coherence interne, une duree, une combinaison de composantes.\n'
        || E'Importer THR dans GENECO reduirait un phenomene structurel a une mesure\n'
        || E'de volatilite -- incohérent avec la finalite de detection economique de GENECO.\n'
        || E'\nRule 4 GENECO actee :\n'
        || E'Les configurations economiques significatives detectees par GENECO font l''objet\n'
        || E'd''un audit annuel independant. Cet audit vise a examiner les mecanismes\n'
        || E'economiques observes, leur coherence methodologique et leurs implications\n'
        || E'potentielles pour l''exercice de la souverainete dans un contexte de conflit.\n'
        || E'Les resultats de cette revue alimentent les analyses et les propositions\n'
        || E'de solutions de l''OSA.\n'
        || E'\nDefinition actee -- configuration economique significative :\n'
        || E'Une combinaison coherente de phenomenes observables ayant une materialite\n'
        || E'mesurable, dont l''analyse laisse raisonnablement supposer l''existence d''un\n'
        || E'mecanisme economique susceptible de fragiliser durablement l''exercice de la\n'
        || E'souverainete d''un Etat dans un contexte de conflit.\n'
        || E'Cette definition est independante de tout algorithme.\n'
        || E'\nPoint ouvert residuel :\n'
        || E'Critere operationnel de selection des configurations significatives a auditer --\n'
        || E'a definir lors de GENECO v2. Ne bloque pas l''orientation du present finding.\n'
        || E'\nRule 4 AMAR (reference) : resolue par AMAR Trigger Engine Sprint 25.\n'
        || E'Rule 4 GENECO : resolue par la presente decision doctrinale.',

    raw_finding = raw_finding || jsonb_build_object(
        'resolution_sprint28', jsonb_build_object(
            'decided_at',       '2026-06-25',
            'decided_by',       'Conseil technique OSA',
            'status_change',    'OPEN -> ORIENTED',
            'option_retained',  'Option B modifiee -- Rule 4 GENECO autonome sans THR',

            'doctrinal_rationale', jsonb_build_object(
                'thr_exclusion', 'THR est un concept AMAR (rupture ponctuelle). GENECO observe des mecanismes structurels durables -- natures incompatibles.',
                'mechanism_vs_threshold', 'Un mecanisme est une combinaison coherente, pas un seuil de declenchement.',
                'algorithmic_independence', 'La definition de configuration significative est independante de tout algorithme.'
            ),

            'rule_4_geneco', jsonb_build_object(
                'text', 'Les configurations economiques significatives detectees par GENECO font l''objet d''un audit annuel independant. Cet audit vise a examiner les mecanismes economiques observes, leur coherence methodologique et leurs implications potentielles pour l''exercice de la souverainete dans un contexte de conflit. Les resultats de cette revue alimentent les analyses et les propositions de solutions de l''OSA.',
                'validated_by', 'Conseil technique OSA',
                'validated_at', '2026-06-25'
            ),

            'significant_configuration_definition', jsonb_build_object(
                'text', 'Une combinaison coherente de phenomenes observables ayant une materialite mesurable, dont l''analyse laisse raisonnablement supposer l''existence d''un mecanisme economique susceptible de fragiliser durablement l''exercice de la souverainete d''un Etat dans un contexte de conflit.',
                'property', 'Independante de tout algorithme',
                'validated_by', 'Conseil technique OSA',
                'validated_at', '2026-06-25'
            ),

            'open_point_residual', jsonb_build_object(
                'description', 'Critere operationnel de selection des configurations significatives a auditer',
                'target',      'GENECO v2',
                'blocking',    false
            ),

            'rule_4_amar_reference', jsonb_build_object(
                'status',   'Resolue -- AMAR Trigger Engine Sprint 25',
                'finding',  'finding #23 AMAR_TRIGGER_PREREQUISITES_VALIDATED'
            )
        )
    ),
    updated_at = now()

WHERE finding_id = 21
  AND finding_code = 'GENECO_ANALYTICAL_INDEPENDENCE';

-- Verification
SELECT
    finding_id,
    finding_code,
    status,
    updated_at,
    raw_finding->'resolution_sprint28'->'rule_4_geneco'->>'validated_at' AS rule4_validated_at,
    raw_finding->'resolution_sprint28'->>'status_change' AS status_change
FROM ops.audit_findings
WHERE finding_id = 21;

COMMIT;
