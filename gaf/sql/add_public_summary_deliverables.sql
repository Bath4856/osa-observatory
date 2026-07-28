-- ============================================================
-- osoa.strategic_deliverables -- resume executif public FR/EN
-- 28 juillet 2026
-- ============================================================
-- Doctrine actee : le livrable ETUDE_OPPORTUNITE (= la Vision) doit
-- porter un resume executif academique/scientifique bilingue, destine
-- aux donnees ouvertes -- distinct du contenu JSON structure brut
-- (swot/cadrage/risques/...), qui reste interne.
--
-- SCHEMA_DIRECTEUR et PLAN_ACTION restent PAYANTS (donnees Go-To-Market),
-- meme niveau que l'etude de faisabilite deja actee premium (Sprint 31) --
-- aucun resume public prevu pour ces deux types, cette colonne ne les
-- concerne pas fonctionnellement (mais reste techniquement disponible
-- si la doctrine change).
--
-- Redaction : genere automatiquement par IA a partir du contenu JSON
-- structure, PUIS valide/corrige par un humain avant toute publication
-- reelle -- summary_status trace ce cycle (jamais publie sans passage
-- par HUMAN_VALIDATED).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE osoa.strategic_deliverables
    ADD COLUMN public_summary_fr text;

ALTER TABLE osoa.strategic_deliverables
    ADD COLUMN public_summary_en text;

ALTER TABLE osoa.strategic_deliverables
    ADD COLUMN summary_status character varying(20) NOT NULL DEFAULT 'PENDING';

ALTER TABLE osoa.strategic_deliverables
    ADD CONSTRAINT chk_deliverables_summary_status CHECK (
        summary_status IN ('PENDING', 'AI_DRAFTED', 'HUMAN_VALIDATED')
    );

COMMIT;

-- Verification post-execution
\d osoa.strategic_deliverables
