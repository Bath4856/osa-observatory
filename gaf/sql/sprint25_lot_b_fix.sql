-- ============================================================
-- Sprint 25 -- Lot B : Correction anomalie SDN 2024 PENV
-- + GAF finding qualite donnees WKN_PENV NULL
-- 23 juin 2026
-- ============================================================

BEGIN;

-- ────────────────────────────────────────────────────────────
-- 1. CORRECTION pub.amar_triggers
--    SDN 2024 PENV : wkn_score NULL (pas 0.000), wkn_missing TRUE
--    Cause : COALESCE(NULL, 0) dans ma.v_p7i_risk_source masque
--            l'absence reelle de WKN_PENV en ma.computed_values
-- ────────────────────────────────────────────────────────────

UPDATE pub.amar_triggers
SET
    wkn_score   = NULL,
    wkn_missing = TRUE
WHERE country_iso3 = 'SDN'
  AND year        = 2024
  AND pillar_code = 'PENV'
RETURNING
    country_iso3, year, pillar_code,
    trigger_class, thr_score,
    wkn_score, wkn_confidence, wkn_missing;

-- ────────────────────────────────────────────────────────────
-- 2. GAF FINDING : WKN_PENV_NULL_MASKED_SDN_2024
-- ────────────────────────────────────────────────────────────

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

    'WKN_PENV_NULL_MASKED_SDN_2024',

    encode(sha256('WKN_PENV_NULL_MASKED_SDN_2024|ma.v_p7i_risk_source|SDN|2024'::bytea), 'hex'),

    'MEDIUM',

    'NONE',

    0.00,

    'VIEW',

    'ma.v_p7i_risk_source',

    E'Anomalie qualite donnees identifiee lors du backfill Lot B Sprint 25 (23 juin 2026).\n\n'
    || E'CONSTAT\n'
    || E'SDN 2024 PENV : WKN_PENV absent en ma.computed_values (value=NULL, confidence=0.000, nb_indicators=2). '
    || E'La vue source ma.v_p7i_risk_source retourne weakness_score=0.000 via COALESCE(NULL, 0), masquant silencieusement l''absence de valeur. '
    || E'swot_data_status=WKN_THR_AVAILABLE confirme que le moteur SWOT a detecte une disponibilite partielle.\n\n'
    || E'IMPACT\n'
    || E'Le backfill initial a charge wkn_score=0.000 et wkn_missing=FALSE dans pub.amar_triggers pour SDN 2024 PENV. '
    || E'Cette representation est incorrecte : wkn_score aurait du etre NULL et wkn_missing=TRUE. '
    || E'La classification TRIGGER_EXCEPTIONAL (thr=1.000 >= 0.40) est inaffectee -- Option B garantit que l''absence de WKN ne neutralise pas un signal exceptionnel. '
    || E'Impact publication : nul. Impact sur la classification : nul. Impact sur la fiabilite des metadonnees qualite : reel.\n\n'
    || E'CORRECTION APPLIQUEE\n'
    || E'UPDATE pub.amar_triggers SET wkn_score=NULL, wkn_missing=TRUE WHERE country_iso3=''SDN'' AND year=2024 AND pillar_code=''PENV''. '
    || E'Correction executee dans la meme transaction que ce finding (Sprint 25 Lot B).\n\n'
    || E'CAUSE RACINE\n'
    || E'Le COALESCE(weakness_score, 0) dans ma.v_p7i_risk_source est une convention defensive du moteur SWOT (eviter les NULL dans les calculs de score). '
    || E'Cette convention est correcte pour le calcul du strategic_risk_score mais produit une perte d''information '
    || E'lorsque weakness_score est consomme comme donnee source par des systemes aval (pub.amar_triggers, API). '
    || E'La vue source ne distingue pas "faiblesse structurelle reellement nulle" de "absence de donnee masquee par COALESCE".\n\n'
    || E'RECOMMANDATION\n'
    || E'Exposer weakness_score_raw (avant COALESCE) dans ma.v_p7i_risk_source pour permettre aux consommateurs aval '
    || E'de distinguer valeur nulle reelle et absence de donnee. A evaluer en Sprint 26.',

    jsonb_build_object(
        'detected_at',      '2026-06-23',
        'detected_during',  'Sprint 25 Lot B -- backfill pub.amar_triggers',
        'affected_row', jsonb_build_object(
            'country_iso3', 'SDN',
            'year',         2024,
            'pillar_code',  'PENV'
        ),
        'evidence', jsonb_build_object(
            'computed_values', jsonb_build_object(
                'indicator_code',   'WKN_PENV',
                'value',            NULL,
                'confidence',       0.000,
                'nb_indicators',    2
            ),
            'v_p7i_risk_source', jsonb_build_object(
                'weakness_score',           0.000,
                'threat_score',             1.000,
                'observation_confidence',   0.604,
                'swot_data_status',         'WKN_THR_AVAILABLE'
            ),
            'amar_triggers_before', jsonb_build_object(
                'wkn_score',    0.000,
                'wkn_missing',  false
            ),
            'amar_triggers_after', jsonb_build_object(
                'wkn_score',    NULL,
                'wkn_missing',  true
            )
        ),
        'classification_impact', jsonb_build_object(
            'trigger_class',    'TRIGGER_EXCEPTIONAL',
            'affected',         false,
            'reason',           'thr=1.000 >= 0.40 -- Option B : EXCEPTIONAL independant de wkn'
        ),
        'root_cause', jsonb_build_object(
            'object',       'ma.v_p7i_risk_source',
            'mechanism',    'COALESCE(weakness_score, 0) -- convention defensive moteur SWOT',
            'effect',       'Perte distinction valeur_nulle_reelle vs absence_donnee pour consommateurs aval'
        ),
        'recommendation', jsonb_build_object(
            'action',   'Exposer weakness_score_raw (avant COALESCE) dans ma.v_p7i_risk_source',
            'horizon',  'Sprint 26',
            'blocking', false
        ),
        'related_findings', jsonb_build_array(
            jsonb_build_object('finding_id', 23, 'code', 'AMAR_TRIGGER_PREREQUISITES_VALIDATED',
                'relation', 'Option B -- wkn_missing comme attribut qualite')
        )
    ),

    'ORIENTED'
)
RETURNING finding_id, finding_code, status, updated_at;

COMMIT;
