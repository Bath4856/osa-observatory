-- =====================================================================
-- GAF Finding -- Multi-affiliation controlee par pilier (max 3 actifs)
-- Resout le sous-chantier C du finding #33 IDENTITY_TRACEABILITY_BY_CONSENT
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
    'GOVERNANCE-IDENTITY',
    'MULTI_AFFILIATION_CONTROLLED_LIMIT',
    md5('GOVERNANCE-IDENTITY|MULTI_AFFILIATION_CONTROLLED_LIMIT|mg.working_group_members'),
    'INFO',
    'NONE',
    0.00,
    'DOCTRINE_PRINCIPLE',
    'mg.working_group_members + mg.committee_memberships + rf.membership_policy',
    $doc$
Décision de gouvernance -- Multi-affiliation dans le temps, sous-chantier
C du finding #33 IDENTITY_TRACEABILITY_BY_CONSENT.

Constat de départ (verifie le 16 juillet 2026) : les deux structures
d'affiliation n'etaient pas symetriques.
- mg.committee_memberships : aucune contrainte d'unicite -- une personne
  pouvait deja etre active dans plusieurs comites simultanement.
- mg.working_group_members : contrainte idx_wgm_one_active limitait a UN
  SEUL groupe de travail actif, tous piliers confondus -- pas "un par
  pilier", litteralement un seul.

L'historique dans le temps (succession d'affiliations INACTIVE) etait
deja correctement gere par la conception existante -- seule la
simultanéité posait probleme, pas la chronologie.

Decision actee : autoriser jusqu'a 3 groupes de travail actifs
simultanement par affilie -- ni un seul (trop restrictif, empeche un
membre du Comite Technique d'accompagner plusieurs groupes), ni illimite
(perte de sens du rattachement). Limite choisie comme parametre
referentiel (rf.membership_policy), pas une valeur en dur dans le code
applicatif ni dans une contrainte SQL figee -- coherent avec la doctrine
"tout en base" deja appliquee sur ce projet.

Mise en oeuvre :
- Retrait de idx_wgm_one_active (contrainte "exactement un").
- Conservation de uq_working_group_member_active (empeche seulement le
  doublon sur un meme pilier -- reste utile, inchangee).
- Nouvelle table rf.membership_policy, meme convention de nommage que
  les tables *_policy deja existantes (rf.access_level_policy et
  analogues) -- policy_code en cle primaire, valeur, description.
- Declencheur (fonction + trigger) sur mg.working_group_members :
  applique la limite a l'ecriture, en lisant la valeur depuis
  rf.membership_policy plutot que de la coder en dur -- modifiable sans
  toucher au code applicatif ni au schema.

mg.committee_memberships reste inchangee -- deja suffisamment flexible,
aucune contrainte a y ajouter.

Statut : principe acte, migration livree et executee.
    $doc$,
    $json$
{
  "type": "governance_principle",
  "resolves": "IDENTITY_TRACEABILITY_BY_CONSENT_subproject_C",
  "trigger": "cadrage_session_16_juillet_2026",
  "prior_state": {
    "committee_memberships": "no_uniqueness_constraint_already_flexible",
    "working_group_members": "exactly_one_active_total_via_idx_wgm_one_active"
  },
  "decision": "max_3_simultaneous_active_working_groups_per_affiliate",
  "limit_storage": "rf.membership_policy (referential, not hardcoded)",
  "constraints_changed": {
    "dropped": ["idx_wgm_one_active"],
    "kept": ["uq_working_group_member_active"],
    "added": ["trigger enforcing rf.membership_policy limit"]
  },
  "history_over_time": "already_correctly_handled_by_existing_design_no_change_needed",
  "committee_memberships_change": "none",
  "governance_body": "conseil_scientifique_osa",
  "status": "principle_validated_migration_delivered"
}
    $json$,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'MULTI_AFFILIATION_CONTROLLED_LIMIT';
