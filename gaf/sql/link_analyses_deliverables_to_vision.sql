-- ============================================================
-- osoa.strategic_analyses / osoa.strategic_deliverables
-- ajout du lien XOR vers mg.pillar_strategic_vision
-- 25 juillet 2026
-- ============================================================
-- Les 9-10 methodes d'analyse et les 4 livrables ont ete concus il
-- y a deux nuits en pensant uniquement aux PROJETS ponctuels
-- (osoa.opportunities). La reformulation de ce soir exige qu'ils
-- puissent aussi se rattacher a la VISION OIM annuelle
-- (mg.pillar_strategic_vision) -- jamais les deux a la fois, meme
-- patron XOR deja utilise ailleurs dans le projet (ex.
-- document_deposits : client XOR affilie ; transformation_requirements :
-- objectif XOR opportunite).
--
-- A EXECUTER APRES create_pillar_strategic_vision.sql (FK dependante).
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

-- ── osoa.strategic_analyses ────────────────────────────────────────────────────
ALTER TABLE osoa.strategic_analyses
    ALTER COLUMN opportunity_id DROP NOT NULL;

ALTER TABLE osoa.strategic_analyses
    ADD COLUMN vision_id integer REFERENCES mg.pillar_strategic_vision(id);

ALTER TABLE osoa.strategic_analyses
    ADD CONSTRAINT chk_strategic_analyses_owner CHECK (
        (opportunity_id IS NOT NULL AND vision_id IS NULL)
        OR (opportunity_id IS NULL AND vision_id IS NOT NULL)
    );

CREATE INDEX idx_osoa_analyses_vision ON osoa.strategic_analyses (vision_id);

-- ── osoa.strategic_deliverables ─────────────────────────────────────────────────
ALTER TABLE osoa.strategic_deliverables
    ALTER COLUMN opportunity_id DROP NOT NULL;

ALTER TABLE osoa.strategic_deliverables
    ADD COLUMN vision_id integer REFERENCES mg.pillar_strategic_vision(id);

ALTER TABLE osoa.strategic_deliverables
    ADD CONSTRAINT chk_strategic_deliverables_owner CHECK (
        (opportunity_id IS NOT NULL AND vision_id IS NULL)
        OR (opportunity_id IS NULL AND vision_id IS NOT NULL)
    );

CREATE INDEX idx_osoa_deliverables_vision ON osoa.strategic_deliverables (vision_id);

COMMIT;

-- Verification post-execution
\d osoa.strategic_analyses
\d osoa.strategic_deliverables
