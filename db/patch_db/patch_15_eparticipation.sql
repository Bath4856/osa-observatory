-- ============================================================
-- OSA Observatory -- Sprint 15
-- E-participation -- Consultation souveraine africaine
--
-- 1. rf.isa_public_consultation_policy   -- extension 2 types
-- 2. mg.consultation_responses           -- reponses citoyennes
-- 3. ma.v_isa_eparticipation_queue       -- file consultation P7J
-- 4. ma.v_isa_eparticipation_priorities  -- priorites par pays
-- 5. pub.v_isa_public_consultation_topics -- sujets ouverts Couche 0
-- ============================================================

BEGIN;

-- ── 1. Extension rf.isa_public_consultation_policy ───────────
-- Ajout des 2 types de consultation scientifique et doctrinale
INSERT INTO rf.isa_public_consultation_policy
    (consultation_topic_type, topic_label, min_priority_score,
     public_open, notes)
VALUES
    ('SCIENTIFIC_FRAMEWORK_REVIEW',
     'Revue du cadre scientifique ISA',
     0.000,
     TRUE,
     'Consultation ouverte sur les choix methodologiques OSA : indicateurs, '
     'ponderations, bornes de normalisation, doctrine d imputation. '
     'Les retours alimentent l agenda du Conseil scientifique -- pas le pipeline.'),
    ('DOCTRINE_REVIEW',
     'Revue de la doctrine souveraine OSA',
     0.000,
     TRUE,
     'Consultation ouverte sur les decisions doctrinales : seuils AMAR, '
     'familles intervention P7J, doctrine NOT_APPLICABLE, regimes monetaires. '
     'Arbitrage final par le Conseil scientifique.')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE rf.isa_public_consultation_policy IS
'Sprint 15 -- Politique de consultation publique OSA.
7 types : 5 types souverains + SCIENTIFIC_FRAMEWORK_REVIEW + DOCTRINE_REVIEW.
Les retours scientifiques et doctrinaux alimentent le Conseil scientifique.
Arbitrage final : Conseil scientifique, pas le pipeline de calcul.';

-- ── 2. Table mg.consultation_responses ───────────────────────
CREATE TABLE IF NOT EXISTS mg.consultation_responses (
    response_id         BIGSERIAL PRIMARY KEY,
    -- Contexte souverain
    country_iso3        CHAR(3)     NOT NULL,
    year                INT         NOT NULL,
    pillar_code         VARCHAR(10),           -- NULL si consultation globale
    -- Type de consultation
    consultation_type   TEXT        NOT NULL,  -- cf. rf.isa_public_consultation_policy
    -- Contenu
    response_text       TEXT        NOT NULL,
    evidence_url        TEXT,                  -- URL preuve si fournie
    -- Positionnement
    position            TEXT,                  -- SUPPORT / CHALLENGE / NEUTRAL / EVIDENCE
    -- Auteur (anonymise si non affilie)
    submitter_label     TEXT,
    affiliation_id      BIGINT
        REFERENCES rf.affiliations(affiliation_id) ON DELETE SET NULL,
    is_anonymous        BOOLEAN     NOT NULL DEFAULT TRUE,
    -- Moderation
    moderation_status   TEXT        NOT NULL DEFAULT 'PENDING',
                                               -- PENDING / APPROVED / REJECTED
    moderated_at        TIMESTAMPTZ,
    moderation_note     TEXT,
    -- Visibilite
    is_public           BOOLEAN     NOT NULL DEFAULT FALSE,
    -- Metadonnees
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT response_type_check
        CHECK (consultation_type IN (
            'RISK_EVIDENCE_REVIEW',
            'OPPORTUNITY_EXPLORATION_FEEDBACK',
            'WEAKNESS_DIAGNOSTIC_REVIEW',
            'STRENGTH_REPLICATION_FEEDBACK',
            'GENERAL_OBSERVATORY_FEEDBACK',
            'SCIENTIFIC_FRAMEWORK_REVIEW',
            'DOCTRINE_REVIEW'
        )),
    CONSTRAINT response_position_check
        CHECK (position IN ('SUPPORT','CHALLENGE','NEUTRAL','EVIDENCE') OR position IS NULL),
    CONSTRAINT moderation_status_check
        CHECK (moderation_status IN ('PENDING','APPROVED','REJECTED'))
);

COMMENT ON TABLE mg.consultation_responses IS
'Sprint 15 -- Reponses citoyennes et institutionnelles aux consultations OSA.
7 types de consultation. Moderation obligatoire avant publication.
Les retours SCIENTIFIC_FRAMEWORK_REVIEW et DOCTRINE_REVIEW alimentent le Conseil scientifique.';

-- Index
CREATE INDEX IF NOT EXISTS idx_consult_country_year
    ON mg.consultation_responses (country_iso3, year);
CREATE INDEX IF NOT EXISTS idx_consult_type
    ON mg.consultation_responses (consultation_type);
CREATE INDEX IF NOT EXISTS idx_consult_moderation
    ON mg.consultation_responses (moderation_status);
CREATE INDEX IF NOT EXISTS idx_consult_pillar
    ON mg.consultation_responses (pillar_code) WHERE pillar_code IS NOT NULL;

-- ── 3. Vue ma.v_isa_eparticipation_queue ─────────────────────
-- File de consultation prioritaire par pays/pilier/annee
-- Source : P7J + politiques eparticipation
CREATE OR REPLACE VIEW ma.v_isa_eparticipation_queue AS
WITH ranked AS (
    SELECT
        r.country_iso3,
        r.year,
        r.pillar_code,
        r.trajectory_class,
        r.intervention_priority_class,
        r.intervention_priority_score,
        r.consultation_theme,
        r.intervention_family_label,
        r.intervention_family_code,
        ca.region_code,
        rg.name_fr                              AS region_label,
        -- Type de consultation selon trajectoire
        CASE
            WHEN r.trajectory_class = 'CRITICAL'
            THEN 'RISK_EVIDENCE_REVIEW'
            WHEN r.trajectory_class = 'DECLINING'
            THEN 'WEAKNESS_DIAGNOSTIC_REVIEW'
            WHEN r.trajectory_class IN ('ACCELERATING','PROGRESSING')
            THEN 'STRENGTH_REPLICATION_FEEDBACK'
            WHEN r.trajectory_class = 'STABLE'
             AND r.intervention_priority_class = 'PRIORITY_HIGH'
            THEN 'OPPORTUNITY_EXPLORATION_FEEDBACK'
            ELSE 'GENERAL_OBSERVATORY_FEEDBACK'
        END                                     AS consultation_type,
        -- Priorite de file
        CASE r.intervention_priority_class
            WHEN 'PRIORITY_CRITICAL' THEN 1
            WHEN 'PRIORITY_HIGH'     THEN 2
            WHEN 'PRIORITY_STANDARD' THEN 3
            ELSE 4
        END                                     AS queue_priority,
        -- Nombre de reponses existantes
        COUNT(cr.response_id)                   AS nb_responses,
        COUNT(cr.response_id) FILTER (
            WHERE cr.moderation_status = 'APPROVED'
                AND cr.is_public = TRUE
        )                                       AS nb_approved_responses,
        -- Statut consultation
        CASE
            WHEN COUNT(cr.response_id) = 0 THEN 'OPEN_NO_RESPONSE'
            WHEN COUNT(cr.response_id) FILTER (
                WHERE cr.moderation_status = 'APPROVED') > 0
            THEN 'ACTIVE_WITH_RESPONSES'
            ELSE 'OPEN_PENDING_MODERATION'
        END                                     AS consultation_status
    FROM ma.v_p7j_recommendation_engine r
    LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = r.country_iso3
    LEFT JOIN rf.regions rg ON rg.code = ca.region_code
    LEFT JOIN mg.consultation_responses cr
        ON  cr.country_iso3      = r.country_iso3
        AND cr.year              = r.year
        AND cr.pillar_code       = r.pillar_code
    WHERE r.year = (SELECT MAX(year) FROM ma.v_p7j_recommendation_engine)
    GROUP BY
        r.country_iso3, r.year, r.pillar_code,
        r.trajectory_class, r.intervention_priority_class,
        r.intervention_priority_score, r.consultation_theme,
        r.intervention_family_label, r.intervention_family_code,
        ca.region_code, rg.name_fr
)
SELECT
    r.*,
    p.requires_moderation,
    p.allows_public_comment,
    p.allows_evidence_upload,
    p.policy_note
FROM ranked r
LEFT JOIN rf.isa_eparticipation_policy p
    ON p.topic_type = r.consultation_type
ORDER BY r.queue_priority, r.intervention_priority_score DESC;

COMMENT ON VIEW ma.v_isa_eparticipation_queue IS
'Sprint 15 -- File de consultation e-participation par pays/pilier.
Source : ma.v_p7j_recommendation_engine + rf.isa_eparticipation_policy.
Type de consultation determine par la trajectoire P7J.
Enrichi par le nombre de reponses citoyennes existantes.';

-- ── 4. Vue ma.v_isa_eparticipation_priorities ────────────────
-- Priorites agregees par pays
CREATE OR REPLACE VIEW ma.v_isa_eparticipation_priorities AS
SELECT
    q.country_iso3,
    q.year,
    q.region_code,
    q.region_label,
    COUNT(*)                                        AS total_consultations,
    COUNT(*) FILTER (WHERE q.consultation_type = 'RISK_EVIDENCE_REVIEW')
                                                    AS nb_risk_reviews,
    COUNT(*) FILTER (WHERE q.consultation_type = 'WEAKNESS_DIAGNOSTIC_REVIEW')
                                                    AS nb_weakness_reviews,
    COUNT(*) FILTER (WHERE q.consultation_type = 'OPPORTUNITY_EXPLORATION_FEEDBACK')
                                                    AS nb_opportunity_feedbacks,
    COUNT(*) FILTER (WHERE q.consultation_type = 'STRENGTH_REPLICATION_FEEDBACK')
                                                    AS nb_strength_feedbacks,
    COUNT(*) FILTER (WHERE q.queue_priority = 1)    AS nb_priority_critical,
    COUNT(*) FILTER (WHERE q.queue_priority = 2)    AS nb_priority_high,
    SUM(q.nb_responses)                             AS total_responses,
    SUM(q.nb_approved_responses)                    AS total_approved_responses,
    -- Score d engagement
    ROUND(
        CASE WHEN COUNT(*) > 0
        THEN (SUM(q.nb_approved_responses)::numeric / COUNT(*))
        ELSE 0 END, 4
    )                                               AS avg_engagement_score,
    -- Statut global
    CASE
        WHEN SUM(q.nb_approved_responses) > 5  THEN 'HIGH_ENGAGEMENT'
        WHEN SUM(q.nb_approved_responses) > 0  THEN 'ACTIVE'
        ELSE                                        'NO_ENGAGEMENT'
    END                                             AS engagement_status
FROM ma.v_isa_eparticipation_queue q
GROUP BY q.country_iso3, q.year, q.region_code, q.region_label
ORDER BY nb_priority_critical DESC, total_consultations DESC;

COMMENT ON VIEW ma.v_isa_eparticipation_priorities IS
'Sprint 15 -- Priorites e-participation agregees par pays.
Score d engagement = reponses approuvees / total consultations.';

-- ── 5. Vue pub.v_isa_public_consultation_topics ───────────────
-- Sujets ouverts Couche 0 -- sans donnees sensibles
CREATE OR REPLACE VIEW pub.v_isa_public_consultation_topics AS
SELECT
    q.country_iso3,
    q.year,
    q.pillar_code,
    q.region_code,
    q.region_label,
    q.trajectory_class,
    q.consultation_type,
    -- Label lisible depuis la politique
    cp.topic_label                              AS consultation_label,
    q.consultation_theme,
    q.intervention_family_label,
    q.queue_priority,
    q.consultation_status,
    q.nb_approved_responses,
    q.allows_public_comment,
    q.allows_evidence_upload,
    -- Appel a participation
    'Share your knowledge at open.osa-observatory.org/consult' AS participation_call,
    'OSA Observatory -- CC-BY-4.0'              AS source
FROM ma.v_isa_eparticipation_queue q
LEFT JOIN rf.isa_public_consultation_policy cp
    ON cp.consultation_topic_type = q.consultation_type
WHERE cp.public_open = TRUE
  AND q.queue_priority <= 3
ORDER BY q.queue_priority, q.country_iso3, q.pillar_code;

COMMENT ON VIEW pub.v_isa_public_consultation_topics IS
'Sprint 15 -- Sujets de consultation publique ouverts -- Couche 0.
Source : ma.v_isa_eparticipation_queue + rf.isa_public_consultation_policy.
Inclut consultations scientifiques et doctrinales OSA.
CC-BY-4.0 -- open.osa-observatory.org';

COMMIT;
