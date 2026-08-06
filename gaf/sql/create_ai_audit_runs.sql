-- ============================================================
-- mg.ai_audit_runs -- historique persistant du laboratoire d'audit IA
-- 7 aout 2026
-- ============================================================
-- Propose par Theo : sans historique, chaque script d'audit perd toute
-- sa valeur des la fermeture du terminal -- impossible de comparer des
-- versions de prompt dans le temps ni de detecter une regression.
--
-- scientific_score reste NULLABLE par conception : derive du verdict de
-- THEO (CONFORME=1.0/A_REVOIR=0.5/PROBLEME_DETECTE=0.0), mais THEO
-- n'intervient qu'APRES la phase complete de generation SCRIBE (doctrine
-- des 2 phases strictes, actee le 6 aout 2026) -- jamais rempli au
-- moment de la generation elle-meme.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.ai_audit_runs (
    id                      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vision_id               integer REFERENCES mg.pillar_strategic_vision(id),
    method                  character varying(30),
    source                  character varying(20) NOT NULL DEFAULT 'AUDIT_SCRIPT',
    provider                character varying(20) NOT NULL,
    model                   character varying(50) NOT NULL,
    prompt_tokens           integer,
    completion_tokens       integer,
    cached_tokens           integer,
    cost_usd                numeric(10,6),
    latency_ms              integer,
    json_valid              boolean,
    schema_valid            boolean,
    scientific_score        numeric(3,2),
    prompt_hash             character varying(64),
    schema_hash             character varying(64),
    error_message           text,
    created_at              timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.ai_audit_runs
    ADD CONSTRAINT chk_ai_audit_runs_source CHECK (
        source IN ('AUDIT_SCRIPT', 'PRODUCTION')
    );

ALTER TABLE mg.ai_audit_runs
    ADD CONSTRAINT chk_ai_audit_runs_score CHECK (
        scientific_score IS NULL OR (scientific_score >= 0 AND scientific_score <= 1)
    );

CREATE INDEX idx_ai_audit_runs_method ON mg.ai_audit_runs (method);
CREATE INDEX idx_ai_audit_runs_prompt_hash ON mg.ai_audit_runs (prompt_hash);
CREATE INDEX idx_ai_audit_runs_created_at ON mg.ai_audit_runs (created_at);

COMMIT;

-- Verification post-execution
\d mg.ai_audit_runs
