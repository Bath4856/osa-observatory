-- ============================================================
-- rf.sovereign_project_catalog -- doctrinal_status + domain_code
-- 27 juillet 2026
-- ============================================================
-- Cloture du point B (convergence P7J/OIM/OSOA). Les 18 projets
-- existants ont ete construits MANUELLEMENT par Theo (Sprint 31),
-- HORS DOCTRINE : ils ne proviennent ni d'un plan d'actions OIM
-- valide, ni d'un AMI/AO/DP reel -- donc ni tracables, ni auditables,
-- ni reproductibles au sens de la doctrine actee cette semaine.
--
-- doctrinal_status distingue cette origine de la colonne "status"
-- EXISTANTE (stade de cycle de vie du projet : CONCEPT/FEASIBILITY/
-- PROTOTYPE/ACTIVE/FUNDED/COMPLETED) -- deux dimensions differentes,
-- ne jamais les confondre. Les 18 existants recoivent LEGACY_MANUAL
-- automatiquement (backfill), puis le DEFAULT est retire : toute
-- nouvelle ligne future doit declarer explicitement son origine
-- legitime (OIM_GENERATED ou EXTERNAL_REQUEST), jamais silencieusement
-- LEGACY_MANUAL par defaut.
--
-- domain_code (nullable) permet de rattacher un projet a un domaine
-- POA reel (rf.poa_phenomenon_domain, cree ce soir) quand pertinent --
-- PAS peuple ce soir pour les 18 existants (rattachement au cas par
-- cas, futur travail du Comite Scientifique, pas une supposition de
-- Claude).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE rf.sovereign_project_catalog
    ADD COLUMN doctrinal_status character varying(20) NOT NULL DEFAULT 'LEGACY_MANUAL';

ALTER TABLE rf.sovereign_project_catalog
    ADD CONSTRAINT chk_sovereign_project_doctrinal_status CHECK (
        doctrinal_status IN ('LEGACY_MANUAL', 'OIM_GENERATED', 'EXTERNAL_REQUEST')
    );

-- Retrait du DEFAULT -- desormais obligatoire de le declarer
-- explicitement pour toute nouvelle ligne (les 18 existants ont deja
-- ete backfilles a LEGACY_MANUAL par le DEFAULT ci-dessus avant ce
-- retrait).
ALTER TABLE rf.sovereign_project_catalog
    ALTER COLUMN doctrinal_status DROP DEFAULT;

ALTER TABLE rf.sovereign_project_catalog
    ADD COLUMN domain_code character varying(30) REFERENCES rf.poa_phenomenon_domain(domain_code);

CREATE INDEX idx_sovereign_project_doctrinal_status ON rf.sovereign_project_catalog (doctrinal_status);

COMMIT;

-- Verification post-execution
SELECT doctrinal_status, COUNT(*) FROM rf.sovereign_project_catalog GROUP BY doctrinal_status;
\d rf.sovereign_project_catalog
