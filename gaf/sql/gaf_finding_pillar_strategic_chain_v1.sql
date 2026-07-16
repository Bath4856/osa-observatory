-- =====================================================================
-- GAF Finding -- PILLAR_STRATEGIC_CHAIN_ARCHITECTURE
-- Cree directement sous ce nom -- verifie le 16 juillet 2026 : aucune
-- version anterieure (PGEO_STRATEGIC_CHAIN_ARCHITECTURE ou autre) n'a
-- jamais ete executee sur osa_db. Ce n'est pas une mise a jour, c'est
-- la premiere ecriture reelle de ce finding.
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
    'PILLAR_STRATEGIC_CHAIN_ARCHITECTURE',
    md5('GOVERNANCE-ENGINEERING|PILLAR_STRATEGIC_CHAIN_ARCHITECTURE|mg.strategic_objectives'),
    'INFO',
    'NONE',
    0.00,
    'ARCHITECTURE_DECISION',
    'mg.pillar_5whys_analysis + mg.pillar_root_causes + mg.strategic_levers + mg.root_cause_levers + mg.strategic_objectives + mg.lever_objectives',
    $doc$
Décision d'architecture -- Chaîne de diagnostic stratégique par pilier.

Origine du nom : identifiée en révisant la page du pilier PGEO
(Géopolitique), qui affichait une recommandation de projet unique sans
chaîne causale ni possibilité de comparaison. Le nom PGEO_* envisagé
initialement documentait cet événement déclencheur, pas la portée de la
décision -- qui couvre les dix piliers, pas seulement PGEO. Corrigé avant
toute exécution : jamais aucune version PGEO_STRATEGIC_CHAIN_ARCHITECTURE
n'a été écrite en base (vérifié le 16 juillet 2026) -- ce finding est créé
directement sous son nom définitif, générique.

Chaîne actée (sept nœuds -- périmètre réduit le 14 juillet 2026, la
version initiale envisagée en comptait onze) :

  Pilier -> Analyse stratégique -> Diagnostic stratégique -> 5 Pourquoi
  -> Cause racine -> Levier(s) stratégique(s) -> Objectif stratégique

Ce finding s'arrête à l'Objectif stratégique. Le pilier reste l'unité de
diagnostic -- pas l'ISA, qui se contente d'orienter vers les piliers
prioritaires. La suite de la chaîne (matching de projets, instanciation,
recommandation) ne relève plus de ce finding -- elle appartient
désormais au finding distinct OIM_ENGINE_CREATION (moteur OIM,
ADR-OSA-OIM-001), volontairement séparé du registre scientifique.

Principes actés :

1. Séparation stricte raisonnement / décision -- le 5 Pourquoi
   (mg.pillar_5whys_analysis) est un processus analytique versionnable
   et rejouable. La cause racine retenue (mg.pillar_root_causes) est sa
   conclusion validée -- seule celle-ci alimente la suite de la chaîne.
   Cette séparation protège la possibilité de faire évoluer ou rejouer
   une analyse sans jamais modifier le modèle en aval.

2. Le levier stratégique n'est pas un objet doctrinal -- mg.strategic_levers
   est un axe d'intervention, pas un phénomène observé. Il n'entre pas
   dans la hiérarchie OSA->ISA->POA->AMAR->GENECO et ne requiert pas de
   validation du Conseil scientifique. Les POA restent intacts.

3. Deux relations N:N pondérées, symétriques, même forme délibérément
   partagée -- chaîne entièrement référentiel-driven, sans branche de
   logique métier cachée dans le code applicatif :
   - mg.root_cause_levers (cause_code, lever_code, relevance_weight)
   - mg.lever_objectives (lever_code, objective_code, relevance_weight)

4. L'objectif stratégique est le nœud central de raccordement --
   mg.strategic_objectives introduit un objet propre plutôt qu'un champ
   de texte libre. C'est le point d'arrivée de cette chaîne (et non plus
   un point intermédiaire, contrairement à la version à onze nœuds
   envisagée initialement) : il devient l'entrée du moteur OIM.

5. mg.sovereign_capabilities -- ÉCARTÉE. Objet conceptuel jugé ni
   nécessaire au diagnostic, ni défini dans la doctrine actuelle
   (Volume 0). Ne pas créer cette table.

6. Zachman -- deux usages distincts, jamais fusionnés. Zachman n°1 :
   cadre méthodologique de gouvernance et de publication ISA (indépendant
   de ce chantier). Zachman n°2 : matrice de conception et de
   gouvernance PROJET, traitée dans le moteur OIM (Phase 3 d'OIM, pas de
   ce finding).

7. Catégorisation 5M -- confirmée, aucun nouveau référentiel. Les "5M"
   correspondent à cause_category_5m, déjà en usage.

8. Phasage -- recentré sur ce seul finding : Phase 1 (diagnostic, unique
   phase) couvre pillar_5whys_analysis, pillar_root_causes,
   strategic_levers, root_cause_levers, strategic_objectives,
   lever_objectives. Tout ce qui suivait (matching, dossiers projets,
   généralisation POA/AMAR/GENECO) est retiré de ce finding et relève
   exclusivement du finding OIM_ENGINE_CREATION.

Gouvernance : suivi par le Conseil technique OSA -- ne relève pas du
Conseil scientifique panafricain (aucun nouvel objet doctrinal, hiérarchie
OSA->ISA->POA->AMAR->GENECO inchangée).

Statut : conception figée (doctrine). Développement non démarré.
    $doc$,
    $json$
{
  "type": "architecture_decision",
  "renamed_from": "PGEO_STRATEGIC_CHAIN_ARCHITECTURE (never actually written to this database)",
  "rename_reason": "trigger_was_PGEO_page_review_but_scope_is_all_10_pillars",
  "chain": [
    "pilier", "analyse_strategique", "diagnostic_strategique",
    "5_pourquoi", "cause_racine", "levier_strategique", "objectif_strategique"
  ],
  "chain_reduced_from_11_to_7_nodes_on": "2026-07-14",
  "chain_continuation": "OIM_ENGINE_CREATION (transformation_requirement -> patrons_compatibles -> instanciation -> famille_de_projets_compatibles)",
  "new_tables_phase1": [
    "mg.pillar_5whys_analysis", "mg.pillar_root_causes", "mg.strategic_levers",
    "mg.root_cause_levers", "mg.strategic_objectives", "mg.lever_objectives"
  ],
  "rejected_tables": ["mg.sovereign_capabilities"],
  "zachman_usages": {
    "n1_publication_governance": "independent, cf. 5w1h_zachman_publication_isa_historique.docx",
    "n2_project_dossier": "phase_3_OIM, distinct matrix, do not merge with n1"
  },
  "cause_taxonomy": "cause_category_5m (existing, unchanged)",
  "doctrinal_impact": "none_on_POA_hierarchy",
  "governance_body": "conseil_technique_osa",
  "status": "design_frozen_dev_not_started_scope_diagnostic_only"
}
    $json$::jsonb,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'PILLAR_STRATEGIC_CHAIN_ARCHITECTURE';
