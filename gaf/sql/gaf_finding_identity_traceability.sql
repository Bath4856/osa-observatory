-- =====================================================================
-- GAF Finding -- Traçabilité de l'identité par consentement explicite
-- Cycle d'audit actif : a592c23b-423e-401f-aee4-a73fddce1129
-- A exécuter sur osa_db (prod) -- décision doctrinale de gouvernance,
-- pas un correctif technique preprod.
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
    'IDENTITY_TRACEABILITY_BY_CONSENT',
    md5('GOVERNANCE-IDENTITY|IDENTITY_TRACEABILITY_BY_CONSENT|mg.affiliates'),
    'INFO',
    'NONE',
    0.00,
    'DOCTRINE_PRINCIPLE',
    'mg.affiliates + mg.isa_eparticipation_feedback + mg.indicator_comments',
    $doc$
Décision de gouvernance -- Séparation Identité / Authentification / Affiliation,
traçabilité comme choix explicite de l'utilisateur.

Déclencheur : revue du parcours de cooptation preprod (fusion mot de passe +
KYC dans le formulaire de confirmation), qui a fait émerger une question de
fond dépassant l'ergonomie de l'écran -- la nature même de la relation entre
une personne, son compte, et sa participation à l'Observatoire.

Principes actés :

1. Trois notions distinctes, jusqu'ici confondues dans une seule table
   mg.affiliates :
   - Identité : qui est la personne (nom, e-mail).
   - Authentification : comment elle se connecte (mot de passe, session).
   - Affiliation : à quel comité, pilier ou groupe de travail elle
     appartient, le cas échéant.
   Une personne peut avoir un compte et participer sans jamais appartenir
   à une structure -- l'inverse aussi (une personne peut être affiliée à
   plusieurs structures au fil du temps).

2. La traçabilité est un choix explicite de l'utilisateur, jamais une
   conséquence implicite de sa participation. Formulation retenue :
   "L'identité n'est jamais déduite des contributions. Elle ne peut être
   associée qu'à la suite d'un consentement explicite au processus KYC."
   Deux catégories d'utilisateurs coexistent :
   - Traçables (KYC validé) : identité associable à leurs contributions,
     fonctions, responsabilités -- seuls éligibles à un rattachement
     comité/pilier/groupe de travail.
   - Anonymisés : participent aux consultations sans conservation
     d'identité. L'équipe technique OSA ne doit jamais chercher à
     réidentifier ni associer ces contributions à une personne physique.

3. Preprod et Production n'ont pas le même métier :
   - Preprod : organisation pilotée -- affiliations décidées par
     cooptation (comité, pilier tranchés avant l'invitation), KYC
     obligatoire fusionné à l'activation du compte.
   - Production : communauté ouverte -- affiliations volontaires,
     un compte peut exister sans appartenance à une structure. Une
     intégration ultérieure à un comité/pilier/groupe de travail suit
     alors le même mécanisme de cooptation que celui de preprod.

4. Le flyer d'invitation (QR code + URL) devient un document de
   gouvernance -- une lettre de mission numérique, pas un simple vecteur
   technique vers un formulaire. Il porte le comité ou le pilier assigné,
   la durée de validité, et matérialise la décision de cooptation.

5. Propagation contrôlée entre environnements : l'identité validée en
   preprod est destinée à être répliquée vers DEV et PROD pour la
   continuité des audits et de la traçabilité -- il ne s'agit pas d'une
   nouvelle inscription mais d'une diffusion contrôlée d'une identité déjà
   validée. Seules certaines données de référence (identité, statut,
   affiliation, métadonnées d'audit) seraient synchronisées -- chaque
   environnement garde son autonomie sur le reste.

Statut : principes actés, schéma cible proposé (Personne -> Compte OSA ->
Participation ouverte | Affiliation officielle). Décomposition du schéma
mg.affiliates et mécanisme de propagation DEV/PREPROD/PROD non
implémentés -- trois sous-chantiers identifiés, à cadrer formellement
avant développement (voir note de conception jointe).

Gouvernance : principe fondateur, dépasse le périmètre d'une décision
technique isolée -- proposé pour validation par le Conseil scientifique
OSA au même titre que les autres principes doctrinaux (conséquentialisme,
P7E observation pure).
    $doc$,
    $json$
{
  "type": "governance_principle",
  "trigger": "preprod_cooptation_form_review",
  "principles": [
    "identity_auth_affiliation_separation",
    "traceability_by_explicit_consent_only",
    "preprod_piloted_vs_prod_open_communities",
    "flyer_as_governance_document",
    "controlled_identity_propagation_across_environments"
  ],
  "target_schema": "Personne -> Compte OSA -> (Participation ouverte | Affiliation officielle)",
  "open_subprojects": [
    "anonymous_participation_mechanism",
    "controlled_dev_preprod_prod_propagation",
    "multi_affiliation_over_time"
  ],
  "current_state": "mg.affiliates conflates identity/auth/affiliation in a single table",
  "governance_body": "conseil_scientifique_osa",
  "status": "principles_validated_implementation_not_started"
}
    $json$,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'IDENTITY_TRACEABILITY_BY_CONSENT';
