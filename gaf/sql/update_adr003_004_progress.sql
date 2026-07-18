-- ============================================================
-- Mise a jour ADR-003 / ADR-004 -- Phase 1 (schema) et Phase 2
-- (migration des donnees, 5 types IDENTITY reels) construites,
-- testees et deployees le 17 juillet 2026 sur DEV/PREPROD/PROD.
-- Phase 3 (adaptation du code applicatif -- affiliation.py appelle
-- emit_governance_event au lieu d'emit_identity_event) NON demarree.
-- mg.identity_events reste seul operationnel.
-- ============================================================

UPDATE rf.adr_registry SET
    description = description || ' Phase 1 (schéma rf.event_types/mg.governance_events) et Phase 2 (migration des 5 types réels IDENTITY, corrigé du chiffre erroné de 2 mentionné dans le document source) construites, testées et déployées le 17 juillet 2026 sur DEV/PREPROD/PROD. Phase 3 (bascule du code applicatif) non démarrée -- mg.identity_events et identity_synchronizer.py restent seuls opérationnels.'
WHERE adr_code = 'ADR-003';

UPDATE rf.adr_registry SET
    description = description || ' Phases 1-2 du plan de migration ADR-003 réalisées le 17 juillet 2026 (voir ADR-003). Renommage identity_synchronizer.py -> governance_synchronizer.py et fiches GAF d''idempotence toujours à produire avant la Phase 3.'
WHERE adr_code = 'ADR-004';

SELECT adr_code, status FROM rf.adr_registry WHERE adr_code IN ('ADR-003', 'ADR-004');
