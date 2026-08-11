-- ============================================================
-- mg.ai_budget_checkpoints -- releves manuels du vrai solde OpenAI
-- 11 aout 2026
-- ============================================================
-- OpenAI n'expose AUCUN endpoint API pour connaitre le solde de credit
-- reel (verifie par recherche le 11 aout 2026, limitation connue et
-- documentee) -- impossible de l'interroger automatiquement. Ce
-- mecanisme reste donc un SUIVI APPROXIMATIF, ancre sur de vrais
-- releves manuels (ex. "$8.16" lu sur le tableau de bord OpenAI),
-- jamais une fausse precision. L'estimation du solde restant a un
-- instant T = dernier releve - depense estimee depuis ce releve
-- (a partir des elements reellement completes depuis, cf fonction
-- d'estimation cote applicatif).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.ai_budget_checkpoints (
    id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    balance_usd     numeric(10,2) NOT NULL,
    note            text,
    created_by      integer REFERENCES mg.affiliates(id),
    created_at      timestamp without time zone NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_budget_checkpoints_created_at ON mg.ai_budget_checkpoints (created_at DESC);

COMMIT;

\d mg.ai_budget_checkpoints
