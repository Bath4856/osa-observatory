-- =====================================================================
-- GAF Finding -- Exigences d'idempotence du bus de gouvernance
-- événementielle (ADR-004 §6, fiche intermédiaire). Formalise les
-- exigences à satisfaire avant mise en production ; sera clôturée par
-- une fiche finale de vérification avant la Phase 6 du plan de
-- migration ADR-003.
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
    'GOVERNANCE-EVENTS',
    'GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS',
    md5('GOVERNANCE-EVENTS|GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS|intermediate'),
    'MEDIUM',
    'NONE',
    0.00,
    'REQUIREMENTS_CHECKLIST',
    'mg.governance_events + api/services/governance_events.py + governance_synchronizer.py',
    $doc$
ADR-004 §6 exige une vérification formelle de l'idempotence du bus de
gouvernance événementielle avant toute mise en production, au moyen de
deux fiches GAF distinctes. Le présent finding constitue la première --
il formalise les exigences à satisfaire, sans encore les vérifier :
l'implémentation (Phases 3-4 du plan de migration ADR-003) n'a pas
commencé au moment de la rédaction de ce finding. Une fiche finale de
vérification sera produite avant la Phase 6, qui clôturera celui-ci.

Quatre exigences actées, reprises du point 6 de la validation
stratégique ADR-004 :

1. Contraintes d'unicité
   L'expérience du domaine IDENTITY (finding #36, ADR-002) a montré
   que "ON CONFLICT DO NOTHING" sans contrainte réelle ne protège rien.
   Pour le bus généralisé, toute logique métier appelée par
   apply_sync_event (ou son équivalent générique) doit s'appuyer sur
   des contraintes d'unicité réelles (index uniques, y compris
   partiels lorsque l'historique doit être préservé -- cf. le motif
   déjà appliqué à mg.committee_memberships et
   mg.working_group_members), jamais sur la seule absence d'erreur
   SQL comme preuve d'idempotence.

2. Comportement au rejeu d'un événement
   Un événement déjà appliqué avec succès en environnement cible, puis
   rejoué (retry réseau, exécution manuelle répétée, ou -- nouveauté
   du bus généralisé -- reprise automatique des événements FAILED en
   plus de PENDING, cf. gouvernance_synchronizer.py) ne doit produire
   aucun effet de bord observable : ni doublon, ni écrasement d'un
   état plus récent par un état plus ancien.

3. Protection contre la double émission
   Deux appels distincts à api/services/governance_events.py pour le
   même fait métier (ex. deux requêtes concurrentes déclenchant la
   même transition d'état) ne doivent pas produire deux événements
   distincts dans mg.governance_events pour un même (object_uuid,
   event_type) dans une fenêtre de temps pertinente, ou, si deux
   événements sont malgré tout créés, leur application côté cible doit
   rester idempotente au sens du point 1.

4. Traitement concurrent
   Deux exécutions simultanées du synchroniseur générique (cas
   normalement évité par une exécution périodique unique, mais à ne
   pas exclure -- ex. chevauchement d'un cron avec une exécution
   manuelle) ne doivent pas produire de double propagation ni de
   corruption du statut d'un même événement.

Portée explicitement hors de ce finding : la distinction entre échec
transitoire et échec permanent dans le synchroniseur reste une dette
technique assumée et documentée séparément (ADR-003, finding #38) --
elle n'est pas une exigence d'idempotence au sens strict et n'est pas
traitée ici.

Statut : exigences formalisées, non encore vérifiées. Implémentation
des Phases 3-4 (ADR-003) à réaliser avant que la fiche finale de
vérification ne puisse être produite et ce finding clôturé.
    $doc$,
    $json$
{
  "type": "requirements_checklist",
  "parent_decision": "ADR-004 §6",
  "supersedes_or_relates_to": ["ADR003_GENERIC_GOVERNANCE_ENGINE (finding #38)", "ADR002_E2E_VALIDATION_LATENT_DEFECTS (finding #36) -- lecon retenue sur ON CONFLICT DO NOTHING"],
  "requirements": [
    {"id": 1, "title": "Contraintes d'unicite reelles", "verified": false},
    {"id": 2, "title": "Comportement au rejeu d'un evenement (PENDING et FAILED)", "verified": false},
    {"id": 3, "title": "Protection contre la double emission", "verified": false},
    {"id": 4, "title": "Traitement concurrent du synchroniseur", "verified": false}
  ],
  "explicitly_out_of_scope": "distinction echec transitoire/permanent -- dette technique assumee separement",
  "closing_finding_required_before": "Phase 6 du plan de migration (ADR-003)",
  "implementation_status_at_time_of_writing": "phases_3_4_not_started",
  "status": "requirements_formalized_verification_pending"
}
    $json$,
    'OPEN'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS';
