INSERT INTO rf.indicator_versions (indicator_code, action, replaced_by, reason, sprint)
VALUES ('MIN_GOV', 'PATCHED', NULL,
'Bug tracabilite source_id : BaseFetcher assigne source_id depuis session connexion (id=14 UN Comtrade) au lieu de data_providers.id=13 (EITI). Donnees correctes, tracabilite incorrecte. Refactoring BaseFetcher prevu Sprint 12 : PROVIDER_CODE doit piloter source_id via data_providers.code.',
'Sprint11');
