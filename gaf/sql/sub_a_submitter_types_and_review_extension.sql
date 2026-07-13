-- ============================================================
-- Sous-chantier A -- Participation anonyme
-- Table référentielle submitter_types + extension du workflow de revue
-- 12 juillet 2026
-- ============================================================
-- Cf. finding GAF DUAL_CONTRIBUTION_CIRCUITS pour la doctrine complète.
-- mg.isa_eparticipation_feedback confirmée vide (0 ligne) avant migration
-- -- aucun risque de violation de contrainte sur des données existantes.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sub_a_submitter_types_and_review_extension.sql
-- ============================================================

BEGIN;

-- 1) Référentiel des types de soumetteur -- remplace le texte libre actuel
CREATE TABLE IF NOT EXISTS rf.submitter_types (
    code           varchar(30) PRIMARY KEY,
    label_fr       text NOT NULL,
    label_en       text NOT NULL,
    description    text,
    display_order  integer NOT NULL DEFAULT 0,
    is_active      boolean NOT NULL DEFAULT true
);

INSERT INTO rf.submitter_types (code, label_fr, label_en, description, display_order) VALUES
    ('PUBLIC', 'Public', 'Public',
     'Visiteur sans compte ni affiliation.', 1),
    ('AFFILIATE_NON_ATTRIBUTED', 'Affilié non attribué', 'Non-attributed affiliate',
     'Affilié OSA choisissant de soumettre sans que son identité soit conservée pour cette contribution.', 2),
    ('ORGANIZATION', 'Organisation', 'Organization',
     'Contribution soumise au nom d''une organisation, sans identité individuelle conservée.', 3),
    ('RESEARCHER', 'Chercheur', 'Researcher',
     'Contribution d''un chercheur non affilié à l''OSA.', 4),
    ('MEDIA', 'Média', 'Media',
     'Contribution d''un organe de presse ou journaliste.', 5),
    ('ADMINISTRATION', 'Administration', 'Administration',
     'Contribution d''une administration publique.', 6)
ON CONFLICT (code) DO NOTHING;

-- 2) Contrainte de cle etrangere sur submitter_type -- actuellement texte
--    libre sans controle. Table confirmee vide, migration sans risque.
ALTER TABLE mg.isa_eparticipation_feedback
    ALTER COLUMN submitter_type SET DEFAULT 'PUBLIC';

ALTER TABLE mg.isa_eparticipation_feedback
    ADD CONSTRAINT isa_eparticipation_feedback_submitter_type_fkey
    FOREIGN KEY (submitter_type) REFERENCES rf.submitter_types(code);

-- 3) Extension du workflow de revue pour accepter les contributions
--    FEEDBACK (pipeline FEEDBACK -> REVIEW -> PROPOSAL -> INDICATOR_COMMENT)
ALTER TABLE mg.contribution_reviews
    DROP CONSTRAINT chk_review_type;

ALTER TABLE mg.contribution_reviews
    ADD CONSTRAINT chk_review_type
    CHECK (contribution_type::text = ANY (ARRAY['TICKET', 'PROPOSAL', 'FEEDBACK']::text[]));

COMMIT;

-- Verification post-execution
SELECT code, label_fr, display_order FROM rf.submitter_types ORDER BY display_order;
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'chk_review_type';
SELECT column_default FROM information_schema.columns
    WHERE table_schema = 'mg' AND table_name = 'isa_eparticipation_feedback' AND column_name = 'submitter_type';
