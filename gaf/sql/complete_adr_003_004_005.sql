-- ============================================================
-- Completion du registre rf.adr_registry -- ADR-003, ADR-004, ADR-005
-- 17 juillet 2026
-- ============================================================
-- Contenu desormais connu (documents recus et lus integralement),
-- remplace les entrees marquees needs_completion=true. Verifie avant
-- ecriture : mg.governance_events / rf.event_types n'existent sur
-- aucune base (confirme le 16 juillet 2026) -- "architecture actee"
-- au sens de ces ADR ne signifie pas "deploye".
-- ============================================================

BEGIN;

UPDATE rf.adr_registry SET
    title_fr = 'Généralisation du moteur de gouvernance événementielle',
    title_en = 'Generalization of the event-driven governance engine',
    status = 'ACCEPTED',
    description = 'Migration d''identity_events (ADR-001/002) vers un moteur générique multi-domaines : rf.event_types (domain_code, code, ...), mg.governance_events (domain_code, event_type, object_type, object_uuid, payload, ...). IDENTITY devient le premier domaine branché, pas la définition du mécanisme. Plan de migration en 6 phases, aucune exécutée à ce jour -- vérifié le 16 juillet 2026, ni rf.event_types ni mg.governance_events n''existent sur aucune base. Architecture actée, mise en œuvre non démarrée.',
    needs_completion = false
WHERE adr_code = 'ADR-003';

UPDATE rf.adr_registry SET
    title_fr = 'Le bus de gouvernance événementielle de l''OSA',
    title_en = 'OSA''s event-driven governance bus',
    status = 'ACCEPTED',
    description = 'S''appuie sur ADR-001, ADR-002, ADR-003 -- ne les remplace pas, en élève l''ambition. Le bus devient le canal unique de propagation pour tout actif gouverné futur (GOVERNANCE, REPOSITORY, METHODOLOGY, DATA, PUBLICATION, PRODUCT, PARTNERSHIP -- aucun engagé par ce document). Renomme identity_synchronizer.py en governance_synchronizer.py. Exige deux fiches GAF d''idempotence (exigences, puis vérification) avant toute mise en production. Coexistence assumée avec le mécanisme identité existant jusqu''à la Phase 6 du plan de migration ADR-003 -- non démarrée.',
    needs_completion = false
WHERE adr_code = 'ADR-004';

UPDATE rf.adr_registry SET
    title_fr = 'Modèle de données du catalogue de livrables Go-To-Market',
    title_en = 'Go-To-Market deliverables catalog data model',
    status = 'PROPOSED',
    former_codes = ARRAY['ADR-003 (a titre indicatif dans le document d''origine, jamais confirme -- collision avec le vrai ADR-003, bus de gouvernance)'],
    related_finding_code = 'GTM_DELIVERABLES_CATALOG_MODEL_001',
    document_path = 'gaf/sql/create_gtm_schema.sql',
    description = 'Schéma gtm dédié (séparé de rf/mm/collect/ma), taxonomies stables dans rf (product_families, diffusion_levels, beneficiary_types), catalogue versionné dans gtm.deliverables. Aucun contrôle d''accès implémenté à ce stade -- prépare seulement la distinction Niveau 1/2 (requires_auth). create_gtm_schema.sql rédigé le 14 juillet 2026, jamais exécuté (confirmé le 16 juillet 2026) -- statut PROPOSITION explicite dans le document d''origine, aucun GAF ni validation formelle encore obtenue.',
    needs_completion = false
WHERE adr_code = 'ADR-005';

UPDATE rf.adr_registry SET
    description = description || ' Absorption planifiée par ADR-003 (plan de migration en 6 phases) -- non démarrée à ce jour. Le mécanisme identité (mg.identity_events, identity_synchronizer.py) reste seul opérationnel et déployé.'
WHERE adr_code = 'ADR-001';

COMMIT;

-- Verification post-execution
SELECT adr_code, status, needs_completion, former_codes FROM rf.adr_registry ORDER BY adr_code;
