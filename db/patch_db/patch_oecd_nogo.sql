-- OECD : pas de fetcher, GOV_EDU sans source alternative
-- Passer en NO_GO jusqu'à implémentation de fetcher_oecd_csv.py
UPDATE collect.source_registry
SET status = 'NO_GO',
    reason = 'Fetcher non implémenté — GOV_EDU sans couverture alternative'
WHERE source_id = 'OECD';
