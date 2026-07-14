-- =====================================================================
-- GAF Finding -- Vérification finale de l'idempotence du bus de
-- gouvernance événementielle (ADR-004 §6). Clôture le finding #39
-- GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS (statut OPEN -> RESOLVED),
-- conformément à l'engagement pris : une fiche finale confirmant la
-- vérification effective des 4 exigences formalisées, avant la
-- Phase 6 du plan de migration (ADR-003).
-- Cycle d'audit actif : a592c23b-423e-401f-aee4-a73fddce1129
-- A exécuter sur osa_db (prod)
-- =====================================================================

SELECT audit_id, audit_timestamp
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- 1) Clôture du finding intermédiaire #39
UPDATE ops.audit_findings
SET status = 'RESOLVED'
WHERE finding_code = 'GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS';

-- 2) Fiche de vérification finale
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
    'GOVERNANCE_BUS_IDEMPOTENCE_VERIFIED',
    md5('GOVERNANCE-EVENTS|GOVERNANCE_BUS_IDEMPOTENCE_VERIFIED|final'),
    'MEDIUM',
    'NONE',
    0.00,
    'VERIFICATION_RESULT',
    'mg.governance_events + governance_synchronizer.py + api/services/governance_events.py',
    $doc$
Vérification finale de l'idempotence du bus de gouvernance événementielle
(ADR-004 §6), clôturant le finding intermédiaire #39
GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS. Les quatre exigences formalisées
ont été vérifiées par des tests réels sur osa_preprod, avec un affilié
de test jetable (test.adr004.bus@example.com, créé via cooptation,
supprimé en fin de vérification -- aucune trace résiduelle), et non par
simple relecture de code. Cette vérification a révélé trois défauts
réels, corrigés séance tenante -- exactement le rôle attendu de
l'environnement PREPROD dans la doctrine de l'Observatoire.

--------------------------------------------------------------------
Exigence 1 -- Contraintes d'unicité réelles
--------------------------------------------------------------------
Méthode : rejeu explicite d'un événement WORKING_GROUP_ACTIVATED déjà
appliqué avec succès (remise en PENDING, relance du synchroniseur).
Résultat : aucun doublon dans mg.working_group_members -- confirmé
COUNT(*) = 1 avant et après rejeu. La protection s'appuie sur l'index
unique partiel uq_working_group_member_active (créé lors de la
validation ADR-002, finding #36), et non sur la seule absence d'erreur
SQL de ON CONFLICT DO NOTHING.
Statut : VÉRIFIÉ.

--------------------------------------------------------------------
Exigence 2 -- Comportement au rejeu d'un événement
--------------------------------------------------------------------
Méthode : rejeu explicite d'un événement AFFILIATE_CONFIRMED déjà
appliqué avec succès (remise en PENDING, relance du synchroniseur).
Résultat : le rejeu a emprunté la branche "updated" (mise à jour de
profil), jamais "created" -- COUNT(*) = 1 dans mg.affiliates avant et
après. Aucun doublon, aucun écrasement d'un état plus récent par un
état plus ancien.
Statut : VÉRIFIÉ.

--------------------------------------------------------------------
Exigence 3 -- Protection contre la double émission
--------------------------------------------------------------------
Méthode : rejeu du formulaire de confirmation d'email (POST
confirm-email/{token}) avec un token déjà consommé.
Résultat : requête rejetée explicitement ("Ce lien a déjà été
utilisé"), aucun nouvel événement inséré dans mg.governance_events --
COUNT(*) = 2 (les deux événements originaux) avant et après tentative.
La protection est portée par la consommation du token
(email_confirmation_tokens.used_at), en amont du bus lui-même.
Statut : VÉRIFIÉ pour le domaine IDENTITY. Limite explicitement notée :
cette protection est propre au mécanisme de token de ce domaine --
tout domaine futur devra fournir sa propre protection contre la double
émission au niveau de sa logique métier ; le bus ne fournit pas cette
garantie de façon générique.

--------------------------------------------------------------------
Exigence 4 -- Traitement concurrent
--------------------------------------------------------------------
Méthode : deux instances de governance_synchronizer.py lancées
simultanément sur le même événement PENDING.
Résultat : une seule instance a réservé et traité l'événement, l'autre
a immédiatement rapporté "Aucun événement en attente" -- confirmant le
fonctionnement de FOR UPDATE SKIP LOCKED. Aucun doublon côté cible.
Statut : VÉRIFIÉ.

--------------------------------------------------------------------
Trois défauts réels découverts et corrigés pendant la vérification
--------------------------------------------------------------------
1. Boucle infinie du synchroniseur -- la première version de
   governance_synchronizer.py reprenait indéfiniment, au sein d'une
   même exécution, tout événement repassé en FAILED. Corrigé par
   exclusion explicite des événements déjà traités dans l'exécution
   courante (processed_uuids) ; un FAILED n'est retenté qu'au
   lancement suivant du script.

2. Ambiguïté d'ordre entre événements d'une même transaction --
   AFFILIATE_CONFIRMED et WORKING_GROUP_ACTIVATED, émis dans la même
   transaction PostgreSQL (confirm_email), partageaient un created_at
   strictement identique (NOW() figé pour toute la durée d'une
   transaction). Sans tiebreaker fiable, WORKING_GROUP_ACTIVATED a été
   réservé avant AFFILIATE_CONFIRMED lors d'un test réel, provoquant
   un 409 (dépendance métier violée : l'affilié doit exister avant son
   rattachement). Corrigé par l'ajout d'une colonne de séquence
   (seq, BIGSERIAL), garantissant l'ordre réel d'insertion
   indépendamment de NOW().

3. Verrou IN_PROGRESS orphelin après interruption -- confirmé en test
   réel (interruption brutale de deux instances concurrentes, piège de
   shell sans lien avec le bus lui-même) : un événement réservé puis
   abandonné restait bloqué en IN_PROGRESS indéfiniment, le
   synchroniseur ne relisant que PENDING/FAILED. Corrigé par l'ajout
   d'une colonne claimed_at, horodatée à la réservation : un
   IN_PROGRESS n'est repris que si son verrou date de plus de 2
   minutes (tres superieur au timeout HTTP de 15s), distinguant un
   verrou orphelin d'un traitement legitime en cours.

--------------------------------------------------------------------
Limites assumées, non résolues par cette vérification
--------------------------------------------------------------------
- Distinction transitoire/permanent dans le synchroniseur -- un
  événement en échec permanent (ex. conflit 409 réel, pas transitoire)
  serait retenté indéfiniment à chaque lancement, sans alerte
  automatique (dette technique déjà actée, finding #38).
- Un verrou IN_PROGRESS orphelin de moins de 2 minutes ne peut pas être
  distingué d'un traitement légitime en cours -- fenêtre résiduelle
  acceptée, largement supérieure au temps de traitement normal
  (timeout HTTP 15s).
- La protection contre la double émission (exigence 3) est
  spécifique au mécanisme de token du domaine IDENTITY, pas une
  garantie générique du bus -- à concevoir explicitement pour tout
  domaine futur.

--------------------------------------------------------------------
Portée de la vérification et suite
--------------------------------------------------------------------
Vérification réalisée exclusivement sur osa_preprod, conformément à la
décision de développement de cette session. Le cycle complet a été
rejoué de bout en bout (cooptation -> confirmation -> émission ->
propagation -> compte PROD -> rattachement), satisfaisant
explicitement la Phase 5 du plan de migration ADR-003
("Revalider le cycle complet ADR-002 §6 sur le nouveau schéma, avec un
nouvel affilié de test jetable"). La Phase 6 (décommissionnement de
mg.identity_events et rf.identity_event_types) reste à réaliser --
non engagée par cette fiche.
    $doc$,
    $json$
{
  "type": "verification_result",
  "closes_finding": "GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS (#39)",
  "parent_decision": "ADR-004 §6",
  "test_method": "real_tests_on_osa_preprod_not_code_review",
  "test_account_email": "test.adr004.bus@example.com",
  "cleanup_completed": true,
  "requirements_verified": [
    {"id": 1, "title": "Contraintes d'unicite reelles", "method": "rejeu WORKING_GROUP_ACTIVATED", "result": "verified", "no_duplicate": true},
    {"id": 2, "title": "Comportement au rejeu d'un evenement", "method": "rejeu AFFILIATE_CONFIRMED", "result": "verified", "branch_taken": "updated_not_created"},
    {"id": 3, "title": "Protection contre la double emission", "method": "rejeu confirm-email avec token consomme", "result": "verified_for_IDENTITY_only", "note": "protection specifique au domaine, pas generique au bus"},
    {"id": 4, "title": "Traitement concurrent", "method": "2 instances simultanees du synchroniseur", "result": "verified", "mechanism": "FOR UPDATE SKIP LOCKED"}
  ],
  "bugs_found_and_fixed_during_verification": [
    {"id": 1, "title": "Boucle infinie sur evenements FAILED", "fix": "exclusion processed_uuids au sein d'une meme execution"},
    {"id": 2, "title": "Ambiguite d'ordre (NOW() transaction-scoped)", "fix": "colonne seq (BIGSERIAL)"},
    {"id": 3, "title": "Verrou IN_PROGRESS orphelin apres crash", "fix": "colonne claimed_at + delai de reprise STALE_LOCK_MINUTES=2"}
  ],
  "known_residual_limits": [
    "pas de distinction echec transitoire/permanent (dette actee, finding #38)",
    "fenetre de 2 minutes ou un IN_PROGRESS recent ne peut pas etre distingue d'un traitement legitime",
    "protection double-emission specifique a IDENTITY, non generique"
  ],
  "adr003_migration_plan_status": {
    "phase_1_schema": "done",
    "phase_2_event_types_migration": "done",
    "phase_3_affiliation_py_adapted": "done",
    "phase_4_generic_synchronizer": "done",
    "phase_5_full_cycle_revalidation": "done_this_session",
    "phase_6_decommission_identity_events": "not_started"
  },
  "status": "requirements_verified_real_conditions"
}
    $json$,
    'RESOLVED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code IN ('GOVERNANCE_BUS_IDEMPOTENCE_REQUIREMENTS', 'GOVERNANCE_BUS_IDEMPOTENCE_VERIFIED')
ORDER BY finding_id;
