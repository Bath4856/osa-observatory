-- =====================================================================
-- GAF Finding -- Deux circuits de contribution (scientifique / e-participation)
-- Résout le sous-chantier A du finding #33 IDENTITY_TRACEABILITY_BY_CONSENT
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
    'DUAL_CONTRIBUTION_CIRCUITS',
    md5('GOVERNANCE-IDENTITY|DUAL_CONTRIBUTION_CIRCUITS|mg.isa_eparticipation_feedback'),
    'INFO',
    'NONE',
    0.00,
    'DOCTRINE_PRINCIPLE',
    'mg.indicator_comments + mg.isa_eparticipation_feedback + mg.contribution_reviews',
    $doc$
Décision de gouvernance -- Deux circuits de contribution distincts et
complémentaires. Résout le sous-chantier A (participation anonyme) du
finding #33 IDENTITY_TRACEABILITY_BY_CONSENT.

Constat de départ : le schéma distinguait déjà, sans que ce soit formalisé,
deux tables de nature différente -- mg.indicator_comments (affiliate_id
obligatoire) et mg.isa_eparticipation_feedback (aucune colonne d'identité,
jamais câblée à un endpoint). Cette note formalise cette séparation comme
un choix d'architecture métier, pas une simple différence technique.

Décisions actées :

1. Deux circuits, deux natures de contribution -- pas une simple bascule
   anonyme/traçable sur un même pipeline :
   - Circuit scientifique (mg.indicator_comments) : réservé aux affiliés,
     authentification et KYC obligatoires, contribution toujours attribuée,
     responsabilité scientifique engagée. Types : 5W1H, SWOT, 5 Pourquoi,
     analyses et propositions méthodologiques.
   - Circuit d'e-participation (mg.isa_eparticipation_feedback) : ouvert
     au public, sans identité conservée. Types : signalement, observation,
     contestation argumentée, suggestion, apport documentaire.

2. La distinction attribué/non-attribué porte sur la contribution, pas sur
   l'utilisateur. Un affilié KYC-validé peut soumettre via le circuit
   d'e-participation sans que son identité y soit jamais enregistrée
   (submitter_type = AFFILIATE_NON_ATTRIBUTED, sans FK vers mg.affiliates).

3. Justification doctrinale : l'OSA traite de sujets sensibles dans
   certains contextes nationaux (gouvernance, ressources naturelles,
   corruption, sécurité, conflits, institutions). Certains signaux
   d'intérêt public ne peuvent raisonnablement être communiqués si leur
   auteur est identifié. La protection porte sur la contribution, jamais
   sur la valeur scientifique qui pourra éventuellement lui être reconnue.

4. Aucune contribution citoyenne n'est jamais publiée directement dans les
   travaux scientifiques de l'OSA -- ni "dé-anonymisée" a posteriori. Le
   signal, s'il est jugé pertinent après revue, donne naissance à une
   NOUVELLE contribution scientifique attribuée (par un affilié ou un
   comité), distincte du signalement d'origine qui reste anonyme en
   permanence :
     FEEDBACK -> REVIEW -> PROPOSAL -> INDICATOR_COMMENT

5. submitter_type (actuellement texte libre, sans contrainte) doit être
   encadré par une table référentielle rf.submitter_types -- cohérent avec
   la doctrine "tout en base, rien en dur" déjà appliquée sur l'ensemble
   du projet.

6. mg.contribution_reviews doit être étendu pour traiter les contributions
   FEEDBACK, actuellement limité à TICKET/PROPOSAL (contrainte
   chk_review_type) -- vérifié le 12 juillet 2026, les 4 étapes de revue
   (TECHNICAL/SCIENTIFIC/ETHICAL/LINGUISTIC) et les 11 verdicts existants
   restent inchangés, suffisamment génériques pour s'appliquer tels quels.

Hors périmètre de ce finding (chantier de développement séparé, à cadrer
individuellement) : endpoint API public de soumission, interface web,
workflow complet de traitement, protection anti-abus sans identité
persistante (limitation de débit, anti-spam).

Statut : principes actés. Socle de données (rf.submitter_types, extension
chk_review_type) livré avec ce finding. Développement applicatif
(endpoint, interface, workflow) non démarré.
    $doc$,
    $json$
{
  "type": "governance_principle",
  "resolves": "IDENTITY_TRACEABILITY_BY_CONSENT_subproject_A",
  "trigger": "cadrage_session_12_juillet_2026",
  "principles": [
    "two_distinct_contribution_circuits",
    "attribution_is_per_contribution_not_per_user",
    "sensitive_context_justifies_non_attribution",
    "no_direct_promotion_without_review_workflow",
    "submitter_type_must_be_referential"
  ],
  "circuits": {
    "scientific": "mg.indicator_comments -- affiliate_id required, always attributed",
    "eparticipation": "mg.isa_eparticipation_feedback -- no identity stored, submitter_type only"
  },
  "promotion_pipeline": ["FEEDBACK", "REVIEW", "PROPOSAL", "INDICATOR_COMMENT"],
  "schema_delivered": ["rf.submitter_types", "chk_review_type extended to include FEEDBACK"],
  "out_of_scope": ["public_api_endpoint", "public_web_interface", "full_treatment_workflow", "anti_abuse_rate_limiting"],
  "governance_body": "conseil_scientifique_osa",
  "status": "principles_validated_schema_delivered_application_not_started"
}
    $json$,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'DUAL_CONTRIBUTION_CIRCUITS';
