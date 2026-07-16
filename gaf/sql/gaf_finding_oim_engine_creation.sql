-- =====================================================================
-- GAF Finding -- OIM_ENGINE_CREATION
-- Corrige le 16 juillet 2026 : liste de colonnes verifiee contre le
-- schema reel de ops.audit_findings (finding_hash, publication_impact,
-- iprs_weight, object_type, object_code absents de la version d'origine
-- -- finding_hash et les trois premiers sont NOT NULL, l'insertion
-- aurait echoue telle quelle).
-- Cycle d'audit actif : a592c23b-423e-401f-aee4-a73fddce1129
-- Résout : ADR-OSA-OIM-001 (ACCEPTED, architecture)
-- Dépend de : PILLAR_STRATEGIC_CHAIN_ARCHITECTURE (amendement du
--   14 juillet 2026, périmètre réduit à Pilier -> Objectif stratégique)
-- A exécuter sur osa_db (prod)
-- =====================================================================

SELECT audit_id, audit_timestamp
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

INSERT INTO ops.audit_findings (
    audit_id,
    module,
    finding_code,
    finding_hash,
    severity,
    publication_impact,
    iprs_weight,
    object_type,
    object_code,
    description,
    raw_finding,
    status
)
SELECT
    audit_id,
    'GOVERNANCE-ENGINEERING',
    'OIM_ENGINE_CREATION',
    md5('GOVERNANCE-ENGINEERING|OIM_ENGINE_CREATION|mg.transformation_requirements'),
    'INFO',
    'NONE',
    0.00,
    'ARCHITECTURE_DECISION',
    'mg.transformation_requirements + mg.intervention_patterns + mg.requirement_pattern_matches',
    $doc$
Finding d'ouverture -- Création du moteur OIM (Operational Intervention
Model), chaîne d'ingénierie distincte de la chaîne scientifique,
conformément à ADR-OSA-OIM-001.

Contexte
--------
Le diagnostic par pilier (PILLAR_STRATEGIC_CHAIN_ARCHITECTURE, périmètre
réduit le 14 juillet 2026) s'arrête désormais à l'Objectif stratégique.
Il ne produit plus de projet ni de recommandation -- c'est un point
d'arrêt volontaire, pas une lacune. OIM prend le relais à partir de ce
point, dans un registre distinct (ingénierie, pas science
d'observation), selon ADR-OSA-OIM-001.

Ce que ce finding ouvre
------------------------
Phase 1 d'OIM uniquement. Rien au-delà.

Objets à créer :
- mg.transformation_requirements
    (objective_code -> requirement, 1:N depuis mg.strategic_objectives)
- mg.intervention_patterns
    (catalogue des Patrons d'Intervention, référentiel)
- mg.requirement_pattern_matches
    (requirement_code, pattern_code, relevance_weight -- N:N pondérée,
    même forme que mg.root_cause_levers et mg.lever_objectives)
- table d'instanciation reliant un patron compatible à une famille de
  projets compatibles (nom exact à trancher au moment du SQL)

Ce que ce finding N'ouvre PAS
-------------------------------
- Aucune sélection de prestataire, aucun pilotage de consortium, aucune
  gestion budgétaire ou contractuelle (domaine exclu, inchangé depuis la
  version initiale d'ADR-OSA-OIM-001).
- Aucune Phase 2 ou 3 d'OIM (matching effectif, dossiers projets).
- Aucune modification du Volume 0, aucun nouvel objet dans la hiérarchie
  ISA/POA/GENECO/AMAR.
- Aucun raccordement technique avec le schéma gtm (catalogue
  Go-To-Market, ADR-003) -- noté pour mémoire uniquement, à examiner
  plus tard.

Gouvernance
-----------
Suivi par le Conseil technique OSA. Ne relève pas du Conseil
scientifique panafricain : OIM reste hors de la chaîne d'observation,
aucun principe du Chapitre 3 du Volume 0 n'est modifié.

Statut : conception figée (ADR-OSA-OIM-001 ACCEPTED). Développement non
démarré. Ce finding autorise le démarrage de la Phase 1 SQL uniquement,
sur validation explicite avant exécution en DEV.

Documents de référence : ADR-OSA-OIM-001 (final), amendement à ADR-004
du 14 juillet 2026, finding PILLAR_STRATEGIC_CHAIN_ARCHITECTURE.
    $doc$,
    $json$
{
  "type": "architecture_decision",
  "resolves": "ADR-OSA-OIM-001",
  "depends_on": "PILLAR_STRATEGIC_CHAIN_ARCHITECTURE",
  "phase_1_objects": [
    "mg.transformation_requirements",
    "mg.intervention_patterns",
    "mg.requirement_pattern_matches",
    "instanciation_table_name_TBD"
  ],
  "explicitly_out_of_scope": [
    "vendor_selection", "consortium_management", "budget_or_contract_management",
    "oim_phase_2_matching", "oim_phase_3_project_dossiers",
    "volume_0_modification", "gtm_schema_technical_link"
  ],
  "governance_body": "conseil_technique_osa",
  "doctrinal_impact": "none_oim_outside_observation_chain",
  "status": "design_frozen_ADR_accepted_dev_not_started_phase1_sql_authorized_pending_dev_validation"
}
    $json$::jsonb,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'OIM_ENGINE_CREATION';
