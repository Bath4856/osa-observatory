-- =====================================================================
-- GAF Finding -- ADR-003 : Généralisation du moteur de gouvernance
-- événementielle. Révise la décision de cadrage prise plus tôt (garder
-- mg.identity_events tel quel, généraliser seulement pour les nouveaux
-- domaines) : l'identité migre elle-même vers le moteur générique.
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
    'ADR003_GENERIC_GOVERNANCE_ENGINE',
    md5('GOVERNANCE-EVENTS|ADR003_GENERIC_GOVERNANCE_ENGINE|rf.event_types+mg.governance_events'),
    'INFO',
    'NONE',
    0.00,
    'ARCHITECTURE_DECISION',
    'rf.event_types + mg.governance_events + identity_synchronizer.py -> synchroniseur générique',
    $doc$
ADR-003 -- Généralisation du moteur de gouvernance événementielle.
Révise une décision de cadrage prise le 14 juillet 2026 dans la même
session : il avait d'abord été acté de conserver mg.identity_events
tel quel et de ne généraliser le moteur événementiel que pour les
futurs domaines (ISA, POA, AMAR, GENECO...). Cette décision est
révisée : l'identité migre elle-même vers le moteur générique, pour
n'avoir qu'un seul pipeline de synchronisation, plutôt que deux
mécanismes parallèles à maintenir indéfiniment.

Contexte de la révision : le document de proposition d'architecture
antérieur à l'ADR-001 posait déjà ce principe ("l'identité constitue
simplement le premier cas d'utilisation de ce moteur"), mais l'ADR-001
et l'ADR-002 ont livré et validé un mécanisme spécifique à l'identité,
faute de retour d'expérience disponible à l'époque. Le cycle complet
ayant depuis été validé de bout en bout (ADR-002 §6) et huit défauts
latents ayant été découverts et corrigés dans ce processus (finding
#36), l'expérience acquise permet désormais de généraliser directement.

Décisions actées :

1. Un seul moteur de gouvernance événementielle pour l'ensemble des
   domaines de l'Observatoire -- identité incluse, et tout domaine
   futur (ISA, POA, AMAR, GENECO, projets stratégiques, paramètres de
   gouvernance) sans qu'un nouveau mécanisme spécifique ne soit
   redéveloppé à chaque fois.

2. Tous les principes doctrinaux de l'ADR-001 sont conservés et
   deviennent les principes fondateurs du moteur générique, appliqués
   uniformément : synchronisation d'événements métier validés jamais
   de tables ; DEV exclu de toute synchronisation ; PREPROD référence
   organisationnelle, PROD réception automatique ; déclenchement
   automatique après validation, jamais d'action manuelle régulière ;
   secrets d'authentification jamais propagés.

3. Schéma cible :
   - rf.event_types (domain_code, code, label_fr, label_en,
     description, is_active) remplace rf.identity_event_types --
     référentiel générique partagé entre domaines, plutôt qu'un
     référentiel par domaine.
   - mg.governance_events (event_uuid, domain_code, event_type,
     object_type, object_uuid, source_environment, target_environment,
     payload, payload_hash, created_at, validated_at, propagated_at,
     propagated_by, status, error_detail) remplace mg.identity_events --
     journal générique, object_uuid reprenant la valeur actuellement
     portée par affiliate_uuid. identity_uuid reste la clé stable du
     domaine identité, seule sa colonne d'accueil change de table.

4. identity_synchronizer.py est remplacé par un synchroniseur générique
   unique, paramétré par domain_code, intégrant d'emblée les deux
   correctifs déjà appris sur le cas identité (échappement SQL réalisé
   côté Python plutôt que par interpolation psql -v/:'var', non
   fonctionnelle dans cet environnement ; reprise automatique des
   événements FAILED en plus de PENDING). Limite assumée comme dette
   technique, non résolue par cette généralisation : absence de
   distinction entre échec transitoire et échec permanent.

5. L'endpoint interne machine-à-machine devient générique :
   POST /api/v1/sync/apply-event { domain_code, event_type,
   object_uuid, payload }, protégé par le même secret partagé que
   l'endpoint actuel, sans changement de doctrine sur ce point.

6. Migration : aucune donnée réelle n'est actuellement portée par
   mg.identity_events (seuls des enregistrements de test, produits et
   nettoyés dans la session précédente) -- la migration ne pose donc
   pas de problème de reprise de données à ce stade du projet. Plan en
   6 phases : création du schéma générique sur les 3 environnements,
   migration des 2 types d'événements existants, adaptation de
   affiliation.py, généralisation du synchroniseur, revalidation
   complète du cycle ADR-002 §6 avec un nouvel affilié de test,
   décommissionnement de mg.identity_events et
   rf.identity_event_types une fois la validation confirmée.

7. Aucun domaine second n'est engagé par cette décision -- le cadrage
   porte sur l'architecture générique elle-même, pas sur un cas
   d'usage. ISA, POA, AMAR, GENECO restent des candidats futurs non
   démarrés.

Statut : architecture actée. Document ADR-003 formalisé
(ADR-003_generalisation_moteur_gouvernance.docx). Mise en œuvre non
démarrée -- plan de migration en 6 phases à exécuter lors d'une
prochaine session.
    $doc$,
    $json$
{
  "type": "architecture_decision",
  "revises": "cadrage_session_14_juillet_2026 (decision initiale : garder identity_events tel quel)",
  "trigger": "retour d'experience ADR-001/ADR-002 valide end-to-end",
  "principle": "un seul moteur de synchronisation evenementielle pour tous les domaines, identite incluse",
  "retained_from_adr001": ["event_driven_not_table_sync", "dev_excluded_from_sync", "preprod_organizational_reference", "prod_receives_only", "automatic_trigger_after_validation", "auth_secrets_never_propagated"],
  "target_schema": {
    "rf.event_types": "remplace rf.identity_event_types, ajoute domain_code",
    "mg.governance_events": "remplace mg.identity_events, ajoute domain_code + object_type, object_uuid remplace affiliate_uuid"
  },
  "synchronizer": "generique, parametre par domain_code, remplace identity_synchronizer.py",
  "internal_endpoint": "POST /api/v1/sync/apply-event (domain_code, event_type, object_uuid, payload)",
  "migration_data_risk": "nul -- mg.identity_events ne contient aucune donnee reelle a ce jour (comptes de test deja nettoyes)",
  "migration_phases": 6,
  "domains_engaged_beyond_identity": [],
  "known_debt_carried_over": "pas de distinction echec transitoire/permanent dans le synchroniseur -- retry indefini sur echec permanent",
  "status": "architecture_validated_implementation_not_started"
}
    $json$,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'ADR003_GENERIC_GOVERNANCE_ENGINE';
