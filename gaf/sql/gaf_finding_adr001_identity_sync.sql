-- =====================================================================
-- GAF Finding -- ADR-001 : Gouvernance des identités et synchronisation
-- entre environnements OSA. Résout le sous-chantier B du finding #33
-- IDENTITY_TRACEABILITY_BY_CONSENT.
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
    'ADR001_EVENT_DRIVEN_IDENTITY_SYNC',
    md5('GOVERNANCE-IDENTITY|ADR001_EVENT_DRIVEN_IDENTITY_SYNC|mg.identity_events'),
    'INFO',
    'NONE',
    0.00,
    'ARCHITECTURE_DECISION',
    'mg.affiliates + mg.identity_events + rf.identity_event_types',
    $doc$
ADR-001 -- Gouvernance des identités et synchronisation entre
environnements OSA. Résout le sous-chantier B (propagation contrôlée
DEV/PREPROD/PROD) du finding #33 IDENTITY_TRACEABILITY_BY_CONSENT.

Principe directeur : la synchronisation ne porte jamais sur des tables --
elle porte sur des événements métier validés. Architecture orientée
événements (event-driven governance) : ce ne sont pas les bases de
données qui sont synchronisées, mais les décisions de gouvernance déjà
validées.

Décisions actées :

1. Rôle des environnements :
   - DEV : développement logiciel, comptes de test libres, données
     fictives autorisées, exclu du mécanisme de synchronisation.
   - PREPROD : référence opérationnelle -- toutes les décisions métier
     (cooptations, création d'affiliés, validation KYC, affectations
     comité/pilier/groupe de travail) y sont prises.
   - PROD : exploitation officielle, ne prend aucune décision
     organisationnelle directement, reçoit uniquement les décisions
     déjà validées en preprod.

2. Déclenchement automatique après validation métier -- pas d'action
   manuelle régulière de l'administrateur. Ceci ne contredit pas le
   principe de traçabilité par consentement explicite (finding #33) :
   le moment explicite est la validation elle-même (cooptation
   approuvée, confirmation d'email + KYC complétés) -- la propagation
   qui en découle est l'exécution fidèle d'une décision déjà prise
   explicitement, pas une nouvelle décision silencieuse.

3. Clé de correspondance stable entre environnements : affiliate_uuid
   (nouvelle colonne mg.affiliates.identity_uuid, générée à la création,
   jamais modifiée), en complément de la contrainte unique existante sur
   l'email. Un UUID stable résiste à un changement d'adresse email futur,
   contrairement à une correspondance fondée sur l'email seul.

4. Données propagées :
   - Identité : identity_uuid, email, first_name, last_name.
   - Profil : function_title, org_name, country.
   - Gouvernance : statut, comité(s), pilier(s), groupe(s) de travail,
     rôle(s), dates de prise d'effet.

5. Données explicitement exclues, propres à chaque environnement :
   password_hash, mg.affiliate_sessions, mg.refresh_tokens,
   mg.revoked_tokens, mg.otp_codes, historique de connexion, journaux
   techniques.

6. Cooptation : mg.cooptation_proposals (documents de travail) ne sont
   jamais synchronisées -- seule la décision finale (l'affiliation
   validée : committee_memberships / working_group_members) est
   propagée. Cohérent avec la décision déjà actée sur le sous-chantier A
   (aucune contribution/décision de travail n'est promue directement,
   seul le résultat validé traverse).

7. Journal d'événements mg.identity_events -- registre de référence des
   synchronisations, portant : identifiant d'événement, type (référencé
   via rf.identity_event_types), affiliate_uuid concerné, environnement
   source et cible, horodatages de création/validation/propagation,
   service propagateur, statut, et un instantané (payload) des données
   propagées avec hash d'intégrité -- ajout à la spécification d'origine,
   nécessaire pour qu'un événement reste fidèle à l'état au moment de sa
   validation, indépendamment de l'état courant de la source au moment
   du traitement par le synchroniseur.

Statut : architecture actée. Socle de données (rf.identity_event_types,
mg.affiliates.identity_uuid, mg.identity_events) livré avec ce finding.
Service de synchronisation ("OSA Identity Synchronizer") non implémenté
-- mécanisme de consommation des événements (push temps réel vs scrutation
périodique) à trancher selon la maturité d'infrastructure disponible,
avant développement.
    $doc$,
    $json$
{
  "type": "architecture_decision",
  "resolves": "IDENTITY_TRACEABILITY_BY_CONSENT_subproject_B",
  "trigger": "cadrage_session_12_juillet_2026",
  "environments": {
    "dev": "excluded_from_sync",
    "preprod": "operational_reference_all_business_decisions",
    "prod": "receives_validated_decisions_only"
  },
  "sync_unit": "validated_business_events_not_tables",
  "trigger_mode": "automatic_after_business_validation",
  "stable_key": "mg.affiliates.identity_uuid",
  "propagated_data": ["identity_uuid", "email", "first_name", "last_name", "function_title", "org_name", "country", "status", "committee_memberships", "working_group_members", "roles", "effective_dates"],
  "excluded_data": ["password_hash", "mg.affiliate_sessions", "mg.refresh_tokens", "mg.revoked_tokens", "mg.otp_codes", "connection_history", "technical_logs"],
  "cooptation_proposals_synced": false,
  "schema_delivered": ["rf.identity_event_types", "mg.affiliates.identity_uuid", "mg.identity_events"],
  "out_of_scope": ["identity_synchronizer_service", "event_emission_triggers", "push_vs_poll_decision"],
  "governance_body": "conseil_scientifique_osa",
  "status": "architecture_validated_schema_delivered_service_not_started"
}
    $json$,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'ADR001_EVENT_DRIVEN_IDENTITY_SYNC';
