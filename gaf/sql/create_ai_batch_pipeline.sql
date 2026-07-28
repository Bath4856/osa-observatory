-- ============================================================
-- mg.ai_batch_jobs / mg.ai_generation_queue -- pipeline batch IA
-- 28 juillet 2026
-- ============================================================
-- Necessaire a l'echelle reelle annoncee par Theo : 540 visions +
-- ~2700 projets issus des plans d'actions + etudes de faisabilite/POC
-- = ~9000 generations/an. En synchrone, se heurterait aux limites de
-- debit OpenAI (RPM/TPM) et prendrait un temps considerable en serie.
-- L'API Batch OpenAI (50% moins cher, jusqu'a 24h de delai) est concue
-- exactement pour ce volume -- coherent avec la doctrine du cycle
-- annuel OIM (recalcule une fois par an au cycle ISA, jamais en temps
-- reel a la demande).
--
-- Portee CE SOIR : fournisseur OpenAI uniquement (format Batch API
-- specifique). Anthropic a sa propre API Batch (Message Batches),
-- format different -- a construire separement si besoin futur, pas
-- duplique ce soir.
--
-- mg.ai_batch_jobs : un job soumis a OpenAI (fichier JSONL, statut,
-- comptage).
-- mg.ai_generation_queue : les demandes individuelles, en attente
-- (QUEUED) puis rattachees a un job une fois soumises (SUBMITTED),
-- puis appliquees en base une fois le resultat recupere (COMPLETED).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.ai_batch_jobs (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider            character varying(20) NOT NULL DEFAULT 'openai',
    provider_batch_id   text,
    status              character varying(20) NOT NULL DEFAULT 'SUBMITTED',
    item_count          integer NOT NULL DEFAULT 0,
    submitted_at        timestamp without time zone NOT NULL DEFAULT now(),
    completed_at        timestamp without time zone,
    created_by          integer REFERENCES mg.affiliates(id)
);

ALTER TABLE mg.ai_batch_jobs
    ADD CONSTRAINT chk_ai_batch_jobs_status CHECK (
        status IN ('SUBMITTED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'EXPIRED')
    );

CREATE TABLE mg.ai_generation_queue (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    generation_type     character varying(30) NOT NULL,
    target_id           integer NOT NULL REFERENCES osoa.strategic_deliverables(id),
    request_payload     jsonb NOT NULL,
    status              character varying(20) NOT NULL DEFAULT 'QUEUED',
    batch_job_id        integer REFERENCES mg.ai_batch_jobs(id),
    error_message       text,
    created_by          integer REFERENCES mg.affiliates(id),
    created_at          timestamp without time zone NOT NULL DEFAULT now(),
    updated_at          timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_generation_type CHECK (
        generation_type IN ('VISION_SUMMARY', 'PLAN_ACTION_EXPLOSION')
    );

ALTER TABLE mg.ai_generation_queue
    ADD CONSTRAINT chk_ai_queue_status CHECK (
        status IN ('QUEUED', 'SUBMITTED', 'COMPLETED', 'FAILED')
    );

CREATE INDEX idx_ai_queue_status ON mg.ai_generation_queue (status);
CREATE INDEX idx_ai_queue_batch_job ON mg.ai_generation_queue (batch_job_id);

COMMIT;

-- Verification post-execution
\d mg.ai_batch_jobs
\d mg.ai_generation_queue
