-- =====================================================================
-- GAF Finding -- Blocage : schema Phase 1 de PILLAR_STRATEGIC_CHAIN_ARCHITECTURE
-- jamais construit, bloque le demarrage effectif d'OIM Phase 1.
-- Cycle d'audit actif : a592c23b-423e-401f-aee4-a73fddce1129
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
    'PILLAR_CHAIN_SCHEMA_MISSING_BLOCKS_OIM',
    md5('GOVERNANCE-ENGINEERING|PILLAR_CHAIN_SCHEMA_MISSING_BLOCKS_OIM|mg.strategic_objectives'),
    'MEDIUM',
    'NONE',
    0.00,
    'DEPENDENCY_GAP',
    'mg.pillar_5whys_analysis + mg.pillar_root_causes + mg.strategic_levers + mg.root_cause_levers + mg.strategic_objectives + mg.lever_objectives',
    $doc$
Ecart bloquant -- Le socle de donnees Phase 1 du finding
PILLAR_STRATEGIC_CHAIN_ARCHITECTURE (#41) n'a jamais ete construit sur
osa_db, malgre le finding doctrinal deja enregistre. Verifie le
16 juillet 2026 : aucune des six tables suivantes n'existe --
mg.pillar_5whys_analysis, mg.pillar_root_causes, mg.strategic_levers,
mg.root_cause_levers, mg.strategic_objectives, mg.lever_objectives.

Consequence concrete : OIM (finding #42, OIM_ENGINE_CREATION) ne peut
pas demarrer sa propre Phase 1 SQL. mg.transformation_requirements
(premiere table d'OIM, cf. ADR-OSA-OIM-001 final) reference
objective_code -> mg.strategic_objectives, qui n'existe pas encore.
Confirme par ADR-OSA-OIM-001 (version finale, 14 juillet 2026) : la
frontiere entre les deux chaines reste inchangee -- ADR-004 s'arrete a
l'Objectif strategique, OIM prend le relais apres ce point avec ses
propres objets (mg.transformation_requirements,
mg.intervention_patterns, mg.requirement_pattern_matches, table
d'instanciation). Les six tables manquantes appartiennent bien au
perimetre ADR-004, pas a OIM -- mais leur absence bloque neanmoins le
demarrage effectif d'OIM en pratique.

Ce finding ne rouvre aucune decision doctrinale deja actee (le finding
#41 reste la reference architecturale) -- il documente uniquement
l'ecart entre conception validee et schema reellement deploye, pour
qu'il ne soit pas perdu de vue avant de commencer OIM.

Action requise avant tout developpement OIM Phase 1 : construire et
executer la migration Phase 1 de PILLAR_STRATEGIC_CHAIN_ARCHITECTURE
(les six tables), sur DEV d'abord conformement a la doctrine deja
etablie sur ce projet (validation en DEV avant PREPROD/PROD), avant
d'entamer le schema propre a OIM.

Statut : ecart identifie, non resolu. Bloquant pour OIM, non bloquant
pour le reste du systeme (aucune autre fonctionnalite n'en depend).
    $doc$,
    $json$
{
  "type": "dependency_gap",
  "blocks": "OIM_ENGINE_CREATION_phase1_sql",
  "blocked_by": "PILLAR_STRATEGIC_CHAIN_ARCHITECTURE_schema_not_deployed",
  "missing_tables": [
    "mg.pillar_5whys_analysis", "mg.pillar_root_causes", "mg.strategic_levers",
    "mg.root_cause_levers", "mg.strategic_objectives", "mg.lever_objectives"
  ],
  "verified_on": "2026-07-16",
  "verified_against": "osa_db",
  "boundary_confirmed_by": "ADR-OSA-OIM-001_final_2026-07-14",
  "boundary_unchanged": true,
  "reopens_finding_41_doctrine": false,
  "required_before_oim_dev": "build_and_run_pillar_chain_phase1_migration_on_DEV_first",
  "status": "gap_identified_unresolved_blocking_for_oim_only"
}
    $json$,
    'OPEN'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'PILLAR_CHAIN_SCHEMA_MISSING_BLOCKS_OIM';
