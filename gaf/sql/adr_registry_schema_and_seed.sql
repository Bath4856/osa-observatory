-- ============================================================
-- rf.adr_registry -- registre unique des decisions d'architecture
-- 17 juillet 2026
-- ============================================================
-- Motivation : trois collisions de numerotation rencontrees en une
-- seule session (PGEO/pilier generique, ADR-003 double sens, OASA vs
-- OSOA) -- aucune source de verite unique n'existait pour les codes
-- ADR avant ce jour. Cette table remplace la dependance a la memoire
-- humaine ou aux conventions de nommage de fichiers.
-- ============================================================
-- EXECUTION -- sur osa_db (registre de gouvernance, propre a la prod) :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < adr_registry_schema_and_seed.sql
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.adr_registry (
    adr_code              text PRIMARY KEY,
    title_fr              text NOT NULL,
    title_en              text NOT NULL,
    status                text NOT NULL DEFAULT 'ACCEPTED'
                          CHECK (status IN ('DRAFT', 'PROPOSED', 'ACCEPTED', 'SUPERSEDED', 'DEPRECATED')),
    superseded_by         text REFERENCES rf.adr_registry(adr_code),
    former_codes          text[],
    related_finding_code  text,
    document_path         text,
    decided_on            date,
    description           text,
    needs_completion       boolean NOT NULL DEFAULT false,
    created_at            timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE rf.adr_registry IS
    'Registre unique des decisions d''architecture (ADR) -- source de '
    'verite remplacant les conventions de nommage de fichiers, qui ont '
    'deja produit plusieurs collisions non detectees (PGEO, ADR-003 '
    'double sens, OASA/OSOA). former_codes conserve la trace des noms '
    'historiques -- ne jamais reutiliser un code deja libere sans '
    'consulter cette colonne.';

COMMENT ON COLUMN rf.adr_registry.needs_completion IS
    'true si le contenu reel du document n''a jamais ete verifie par '
    'Claude au moment de l''enregistrement -- ne pas considerer '
    'description comme fiable tant que ce champ reste true.';

-- ------------------------------------------------------------
-- Seed -- etat connu au 17 juillet 2026. Les champs marques
-- "a completer" reflètent une incertitude reelle, pas une omission.
-- ------------------------------------------------------------

INSERT INTO rf.adr_registry (adr_code, title_fr, title_en, status, former_codes, related_finding_code, document_path, decided_on, description, needs_completion) VALUES

('ADR-001', 'Synchronisation d''identite pilotee par evenements', 'Event-driven identity synchronization',
 'ACCEPTED', NULL, 'ADR001_EVENT_DRIVEN_IDENTITY_SYNC', NULL, '2026-07-16',
 'Propagation controlee PREPROD -> PROD fondee sur des evenements metier valides, pas sur des copies de tables. Construit, teste et deploye (finding #35).',
 false),

('ADR-002', 'KYC conditionne a la cooptation', 'KYC conditioned on cooptation',
 'ACCEPTED', NULL, NULL, NULL, '2026-07-13',
 'KYC obligatoire uniquement pour la cooptation preprod (organisation pilotee) -- pas pour l''affiliation volontaire en production. Endpoints admin/preaffiliate, correctif login AFFILIATED. Cf. commit b9aa6bf.',
 false),

('ADR-003', 'Bus de gouvernance evenementielle -- generalisation (a completer)', 'Event-driven governance bus -- generalization (to complete)',
 'PROPOSED', NULL, NULL, NULL, NULL,
 'Contenu reel jamais verifie par Claude -- connu uniquement par le titre du commit Git 87f4911. mg.governance_events / rf.event_types mentionnes mais jamais executes sur aucune base (verifie le 16 juillet 2026 sur osa_db). A completer avant de faire confiance a cette entree.',
 true),

('ADR-004', 'Bus de gouvernance evenementielle -- migration du domaine identite (a completer)', 'Event-driven governance bus -- identity domain migration (to complete)',
 'PROPOSED', NULL, NULL, NULL, NULL,
 'Meme origine et meme reserve que ADR-003 -- commit 87f4911, jamais execute. Ne PAS confondre avec l''ancien usage informel de "ADR-004" pour le diagnostic par pilier, renomme ADR-006 (voir cette entree).',
 true),

('ADR-005', 'Non identifie', 'Not identified',
 'PROPOSED', NULL, NULL, NULL, NULL,
 'Mentionne comme faisant partie du groupe "ADR-005/006/007 proposes" (note de cadrage OSOA, session du 14 juillet 2026) mais jamais defini nulle part dans les documents recus. Emplacement reserve, contenu inconnu.',
 true),

('ADR-006', 'Diagnostic strategique par pilier', 'Pillar-level strategic diagnostic',
 'ACCEPTED', ARRAY['ADR-004 (usage informel, avant collision identifiee le 14 juillet 2026)'], 'PILLAR_STRATEGIC_CHAIN_ARCHITECTURE', 'gaf/docs/ADR/ADR004_strategic_chain_draft.md', '2026-07-14',
 'Chaine Pilier -> 5 Pourquoi -> Cause racine -> Levier(s) -> Objectif strategique. S''arrete a l''Objectif strategique. Phase 1 (6 tables + rf.cause_category_5m) construite, testee (portee panafricaine et pays), deployee sur DEV/PREPROD/PROD le 17 juillet 2026 -- finding #41 puis #44, desormais RESOLVED.',
 false),

('ADR-007', 'Operational Intervention Model (OIM)', 'Operational Intervention Model (OIM)',
 'ACCEPTED', ARRAY['ADR-OSA-OIM-001 (nom d''origine)'], 'OIM_ENGINE_CREATION', 'gaf/docs/ADR/ADR_OSA_OIM_001_final.md', '2026-07-14',
 'Caracterise les architectures d''intervention compatibles avec un besoin de transformation -- deux chemins d''entree (interne via ADR-006, externe via OSOA). Phase 1 (5 tables) construite, testee bout en bout, deployee sur DEV/PREPROD/PROD le 17 juillet 2026 -- finding #42, desormais RESOLVED. Amendement du 14 juillet 2026 (second chemin d''entree) integre dans le Volume 0 OIM -- nouvelle colonne de reutilisabilite sur mg.intervention_patterns non encore construite (a faire).',
 false)

ON CONFLICT (adr_code) DO NOTHING;

COMMIT;

-- Verification post-execution
SELECT adr_code, status, former_codes, needs_completion FROM rf.adr_registry ORDER BY adr_code;
