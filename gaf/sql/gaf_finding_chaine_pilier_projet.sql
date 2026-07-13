-- =====================================================================
-- GAF Finding — Architecture chaîne Pilier -> Cause -> Levier -> Projet
-- Cycle d'audit actif : a592c23b-423e-401f-aee4-a73fddce1129
-- A exécuter sur osa_db (prod). Vérifier le nom exact des colonnes de
-- ops.audit_findings avant exécution (\d ops.audit_findings) : ce script
-- reprend la structure connue (audit_id, description, raw_finding) mais
-- n'a pas été validé contre le schéma live depuis cet environnement.
-- =====================================================================

-- 1) Ne jamais inventer d'UUID : toujours relire le dernier audit_run.
--    (à exécuter seul d'abord pour vérifier qu'il correspond bien au
--    cycle a592c23b-423e-401f-aee4-a73fddce1129 avant d'insérer)
SELECT audit_id, audit_timestamp
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- 2) Insertion du finding, avec dollar-quoting pour éviter le bug de
--    quoting rencontré sur le finding #31.
INSERT INTO ops.audit_findings (
    audit_id,
    finding_code,
    description,
    raw_finding
)
SELECT
    audit_id,
    'PGEO_STRATEGIC_CHAIN_ARCHITECTURE',
    $doc$
Décision d'architecture — Chaîne de recommandation stratégique par pilier
(Pilier -> Analyse stratégique -> Diagnostic -> 5 Pourquoi -> Cause racine
-> Levier stratégique -> Matching des projets -> Projet recommandé ->
Contribution stratégique attendue).

Déclencheur : revue de la page PGEO, absence de démonstration comparative
et de chaîne causale derrière la recommandation de projet unique livrée
en Sprint 31.

Décisions actées :
1. L'ISA n'est pas le point de départ du raisonnement ; le pilier est
   l'unité de diagnostic, l'ISA oriente vers les piliers prioritaires.
2. Séparation raisonnement / décision : le 5 Pourquoi (processus,
   versionnable, table mg.pillar_5whys_analysis) est distinct de la
   cause racine retenue (conclusion validée, table
   mg.pillar_root_causes), qui seule alimente le matching.
3. Le levier stratégique (table mg.strategic_levers) est un axe
   d'intervention, pas un objet doctrinal observé : il n'entre pas
   dans la hiérarchie OSA -> ISA -> POA -> AMAR -> GENECO et ne
   requiert pas de validation du Conseil scientifique. Les POA restent
   intacts et inchangés.
4. Liaison N:N pondérée cause <-> levier (mg.root_cause_levers,
   relevance_weight).
5. Point ouvert : mg.project_coverage_policies doit être révisée pour
   pointer sur lever_code plutôt que sur cause_category_5m avant
   construction de ma.mv_pillar_project_ranking.

Gouvernance : validée en revue architecte technique / conseil
scientifique OSA. Ne relève pas du Conseil scientifique (pas de nouvel
objet doctrinal) ; suivi par le Conseil technique OSA.

Statut : conception validée, développement non démarré. Phasage en 4
étapes (voir note de conception jointe).
    $doc$,
    $json$
{
  "type": "architecture_decision",
  "product": "P1_ISA",
  "trigger": "PGEO_page_review",
  "new_tables": [
    "mg.pillar_5whys_analysis",
    "mg.pillar_root_causes",
    "mg.strategic_levers",
    "mg.root_cause_levers"
  ],
  "tables_to_revise": [
    "mg.project_coverage_policies"
  ],
  "views_pending": [
    "ma.mv_pillar_project_ranking"
  ],
  "api_impact": [
    "/api/v2/sovereign-projects/recommendation/{iso3}/{pillar}"
  ],
  "doctrinal_impact": "none_on_POA_hierarchy",
  "governance_body": "conseil_technique_osa",
  "status": "design_validated_dev_not_started",
  "phasing": ["phase_1_levers_and_causal_chain", "phase_2_matching_and_view", "phase_3_zachman_project_dossier", "phase_4_generalize_to_POA_AMAR_GENECO"]
}
    $json$
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;
