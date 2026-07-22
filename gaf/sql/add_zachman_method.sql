-- ============================================================
-- osoa.strategic_analyses -- ajout de la methode ZACHMAN
-- 22 juillet 2026
-- ============================================================
-- Zachman deja utilise ailleurs dans le projet (Sprint 8 validation
-- des sources de collecte, Sprint 19 architecture de publication ISA
-- historique) : grille 6x6, 6 colonnes (QUOI/COMMENT/OU/QUI/QUAND/
-- POURQUOI) x 6 lignes de perspective (EXECUTIVE/BUSINESS_MGMT/
-- ARCHITECT/ENGINEER/TECHNICIAN/ENTERPRISE). Ajoute comme 9eme
-- methode valide pour osoa.strategic_analyses, structure complete
-- 6x6 (pas un simple 6W1H a une seule ligne).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE osoa.strategic_analyses
    DROP CONSTRAINT strategic_analyses_method_check;

ALTER TABLE osoa.strategic_analyses
    ADD CONSTRAINT strategic_analyses_method_check CHECK (
        method IN (
            '5W1H', 'SWOT', '5_POURQUOI', 'RISQUE', 'FAISABILITE',
            'MULTICRITERE', 'ECONOMIQUE', 'GOUVERNANCE', 'ZACHMAN'
        )
    );

COMMIT;

-- Verification post-execution
\d osoa.strategic_analyses
