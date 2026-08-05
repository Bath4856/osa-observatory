-- ============================================================
-- Reconciliation Chaine A (ADR-004, Lot 1/2, jamais utilisee) /
-- Chaine B (Vision, validee cette semaine)
-- 5 aout 2026
-- ============================================================
-- Decouverte du 5 aout (matin) : deux chaines OIM paralleles et
-- deconnectees existaient. La Chaine A (mg.pillar_5whys_analysis ->
-- mg.pillar_root_causes -> mg.root_cause_levers -> mg.strategic_levers
-- -> mg.strategic_objectives -> mg.transformation_requirements),
-- concue le 14 juillet (ADR004_strategic_chain_draft.md), construite et
-- testee uniquement en SQL direct, jamais alimentee de vraies donnees
-- (1 ligne de test partout), exposee via API tardivement (commit
-- 7eeb257) mais toujours sans page de portail ni generation IA.
--
-- Decision de Theo : ne pas garder d'etat non utilise. L'entree
-- diagnostique de la Chaine A (5whys_analysis + root_causes) est
-- entierement redondante avec osoa.strategic_analyses/5_POURQUOI
-- (Chaine B, valide sur donnees reelles NAM/PTRA/2024 et CMR/PMIN/2024)
-- -- SUPPRIMEE. Le catalogue partage (strategic_levers, lever_code) et
-- son aval (strategic_objectives, lever_objectives,
-- transformation_requirements) sont CONSERVES -- aucun equivalent dans
-- la Chaine B -- mais reconnectes vers la vraie analyse validee.
--
-- mg.root_cause_levers : root_cause_id (-> mg.pillar_root_causes,
-- supprimee) devient analysis_id (-> osoa.strategic_analyses.id,
-- la 5_POURQUOI PROMOTED de la vision).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

DROP TABLE mg.root_cause_levers;
DROP TABLE mg.pillar_root_causes;
DROP TABLE mg.pillar_5whys_analysis;

CREATE TABLE mg.root_cause_levers (
    analysis_id         integer NOT NULL REFERENCES osoa.strategic_analyses(id),
    lever_code          text NOT NULL REFERENCES mg.strategic_levers(lever_code),
    relevance_weight     numeric(4,2) NOT NULL,
    created_at          timestamp without time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (analysis_id, lever_code)
);

ALTER TABLE mg.root_cause_levers
    ADD CONSTRAINT chk_root_cause_levers_weight CHECK (
        relevance_weight >= 0 AND relevance_weight <= 1
    );

COMMENT ON TABLE mg.root_cause_levers IS
    'Liaison N:N ponderee cause racine <-> levier. analysis_id reference '
    'une analyse osoa.strategic_analyses de methode 5_POURQUOI, idealement '
    'PROMOTED (verifie cote application, pas de contrainte SQL sur la '
    'methode -- reconciliation Chaine A/B du 5 aout 2026).';

COMMIT;

-- Verification post-execution
\d mg.root_cause_levers
