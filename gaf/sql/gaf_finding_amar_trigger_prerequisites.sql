-- ============================================================
-- GAF Finding : AMAR_TRIGGER_PREREQUISITES_VALIDATED
-- Reference documentaire : GAF-AMAR-TRIGGER-002
-- Sprint 25 -- AMAR Trigger Engine
-- Emis le : 23 juin 2026
-- Valide par : Comite technique OSA
-- ============================================================
-- NOTE : verifier finding_id retourne = 23 apres execution.
-- Si un finding a ete insere entre la session du 22 juin et
-- aujourd'hui, ajuster en consequence (le RETURNING le confirme).
-- ============================================================

INSERT INTO ops.audit_findings (
    audit_id,
    module,
    finding_code,
    finding_hash,
    severity,
    publication_impact,
    iprs_weight,
    object_type,
    object_code,
    description,
    raw_finding,
    status
) VALUES (
    'a592c23b-423e-401f-aee4-a73fddce1129',

    'P7I-AMAR',

    'AMAR_TRIGGER_PREREQUISITES_VALIDATED',

    encode(sha256('AMAR_TRIGGER_PREREQUISITES_VALIDATED|P7I-AMAR|Sprint25'::bytea), 'hex'),

    'LOW',

    'NONE',

    0.00,

    'MODULE',

    'P7I-AMAR',

    -- ── DESCRIPTION ────────────────────────────────────────────
    E'GAF-AMAR-TRIGGER-002 -- Validation des prerequis operationnels du moteur de declenchement AMAR (Sprint 25).\n\n'
    || E'CONTEXTE DOCTRINAL\n'
    || E'AMAR constitue le moteur de detection des signaux de risque strategique precurseur. GENECO constitue un moteur d''intelligence analytique identifiant des configurations compatibles avec une dynamique de destruction economique systemique. Les deux moteurs demeurent conceptuellement distincts, meme lorsqu''ils exploitent temporairement les memes sources de donnees.\n\n'
    || E'DECISION 1 -- Gestion de l''incompletude diagnostique\n'
    || E'Le Comite technique adopte l''Option B : hierarchie conditionnelle.\n'
    || E'La classe TRIGGER_DIAGNOSTIC_INCOMPLETE s''applique uniquement lorsque les conditions de declenchement exceptionnelles ne sont pas reunies.\n'
    || E'En consequence :\n'
    || E'(a) un THR inferieur au seuil EXCEPTIONAL et associe a un WKN absent peut etre classe TRIGGER_DIAGNOSTIC_INCOMPLETE ;\n'
    || E'(b) un THR atteignant le seuil EXCEPTIONAL conserve la classification TRIGGER_EXCEPTIONAL meme en presence d''un WKN absent ;\n'
    || E'(c) l''absence de WKN est alors publiee comme attribut de qualite des donnees (flag wkn_missing = TRUE).\n\n'
    || E'Justification : AMAR est un systeme d''alerte precurseur. Un signal exceptionnel ne doit pas etre rendu invisible par une incompletude diagnostique portant sur le contexte structurel. La qualite des donnees constitue une information de confiance et d''interpretation, mais ne doit pas neutraliser la fonction premiere de detection.\n\n'
    || E'DECISION 2 -- Seuil operationnel THR\n'
    || E'Le Comite technique valide les parametres suivants : seuil THR = 0.20 ; declenchement sur un seul pilier ; seuil uniforme et pilier-agnostique ; absence de ponderation specifique par pilier dans la version actuelle.\n\n'
    || E'Justification : la simulation 2020-2024 (ma.v_p7i_risk_source, n=2700) a produit 18 declenchements (0,67% des observations), distribution compatible avec une revue analytique continentale. La calibration est consideree suffisamment discriminante pour une premiere mise en production. Les mecanismes de ponderation par pilier sont reportes au Sprint 2 du Trigger Engine.\n\n'
    || E'CONSEQUENCE DOCTRINALE\n'
    || E'Le moteur AMAR applique desormais la logique suivante :\n'
    || E'THR detecte. WKN contextualise. La qualite des donnees informe. L''incompletude ne neutralise pas un signal exceptionnel.\n\n'
    || E'Application a partir du Sprint 25.',
    -- ── RAW_FINDING ────────────────────────────────────────────
    jsonb_build_object(
        'gaf_reference',        'GAF-AMAR-TRIGGER-002',
        'sprint',               'Sprint 25',
        'validated_at',         '2026-06-23',
        'validated_by',         'Comite technique OSA',

        'decision_1', jsonb_build_object(
            'label',            'Gestion de l''incompletude diagnostique',
            'option_retained',  'Option B -- hierarchie conditionnelle',
            'rules', jsonb_build_array(
                jsonb_build_object(
                    'id',   'B1',
                    'condition', 'THR < seuil_EXCEPTIONAL ET WKN absent',
                    'classification', 'TRIGGER_DIAGNOSTIC_INCOMPLETE'
                ),
                jsonb_build_object(
                    'id',   'B2',
                    'condition', 'THR >= seuil_EXCEPTIONAL ET WKN absent',
                    'classification', 'TRIGGER_EXCEPTIONAL',
                    'note', 'wkn_missing = TRUE publie comme attribut qualite'
                )
            ),
            'canonical_example', jsonb_build_object(
                'country',      'SDN',
                'year',         2024,
                'pillar',       'PENV',
                'thr_score',    1.000,
                'wkn_score',    NULL,
                'classification', 'TRIGGER_EXCEPTIONAL',
                'wkn_missing',  true
            ),
            'justification',    'Un signal exceptionnel ne doit pas etre rendu invisible par une incompletude diagnostique sur le contexte structurel.'
        ),

        'decision_2', jsonb_build_object(
            'label',            'Seuil operationnel THR',
            'thr_threshold',    0.20,
            'granularity',      'Pilier-agnostique -- un seul pilier suffit',
            'weighting',        'Uniforme -- pas de ponderation pilier-specifique en v1',
            'weighting_deferred', 'Sprint 2 Trigger Engine',
            'empirical_basis', jsonb_build_object(
                'source',       'ma.v_p7i_risk_source',
                'period',       '2020-2024',
                'n_total',      2700,
                'n_triggers',   18,
                'trigger_rate_pct', 0.67,
                'assessment',   'Volume compatible avec revue analytique continentale'
            )
        ),

        'doctrinal_principle', jsonb_build_object(
            'thr_role',         'Detecte',
            'wkn_role',         'Contextualise',
            'data_quality_role', 'Informe',
            'incompleteness_rule', 'Ne neutralise pas un signal exceptionnel'
        ),

        'taxonomy_reference', jsonb_build_object(
            'TRIGGER_EXCEPTIONAL',          'THR >= 0.40',
            'TRIGGER_CRITICAL',             'THR >= 0.20 ET WKN >= 0.70 ET conf > 0',
            'TRIGGER_ACTIVE',               'THR >= 0.20 (autres cas)',
            'TRIGGER_DIAGNOSTIC_INCOMPLETE', 'THR >= 0.20 ET THR < 0.40 ET (WKN absent OU conf = 0)'
        ),

        'related_findings', jsonb_build_array(
            jsonb_build_object('finding_id', 20, 'code', 'STRATEGIC_RISK_SIGNAL_DOMINANCE_GREATEST', 'relation', 'Finding source -- diagnostic compression de signal et decision architecture Trigger independant'),
            jsonb_build_object('finding_id', 21, 'code', 'GENECO_ANALYTICAL_INDEPENDENCE', 'relation', 'GENECO Trigger Engine par deduction si v1, re-conception si v2/v3'),
            jsonb_build_object('finding_id', 22, 'code', 'GENECO_OBSERVATIONAL_DOCTRINE_ALIGNMENT', 'relation', 'Doctrine GENECO -- conditionne evolution GENECO Trigger Engine')
        ),

        'cadrage_reference',    'docs/cadrage_sprint25_amar_trigger_engine.docx'
    ),
    -- ── STATUS ─────────────────────────────────────────────────
    'ORIENTED'
)
RETURNING finding_id, finding_code, status, updated_at;
-- NOTE : si validated_at n''existe pas dans la table (colonne non
-- prevue), retirer ce champ du RETURNING et utiliser updated_at.
-- Verifier le schema de ops.audit_findings avant execution.
