-- =====================================================================
-- GAF Finding -- Mecanisme de reinitialisation de mot de passe, formalise
-- comme composant standard du protocole -- pas un contournement ponctuel.
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
    'PASSWORD_RESET_MECHANISM_FORMALIZED',
    md5('GOVERNANCE-IDENTITY|PASSWORD_RESET_MECHANISM_FORMALIZED|mg.password_reset_tokens'),
    'INFO',
    'NONE',
    0.00,
    'DOCTRINE_PRINCIPLE',
    'mg.password_reset_tokens + api/routers/affiliation.py (request_password_reset, reset_password)',
    $doc$
Finding de documentation -- Formalisation du mécanisme de réinitialisation
de mot de passe comme composant standard et permanent du protocole
d'identité, pas un contournement ponctuel improvisé pour débloquer un
compte.

Déclencheur : construit et testé le 11 juillet 2026 (sous-chantier
KYC/mot de passe), utilisé en conditions réelles le 16 juillet 2026 pour
débloquer le compte fondateur -- jamais formellement documenté jusqu'ici,
oubli identifié en fin de session.

Portée du mécanisme :

1. Accessible à TOUT affilié dont le statut est ACTIVE ou AFFILIATED --
   aucune restriction de rôle. Le compte fondateur (id=3 en preprod)
   n'a rien de particulier dans ce mécanisme, c'est simplement le premier
   à l'avoir exercé en conditions réelles.

2. Deux voies coexistent en permanence, pas seulement en cas de blocage :
   - Changement volontaire depuis "Mon espace" (PATCH /me/password),
     exige l'ancien mot de passe -- jamais l'un sans l'autre.
   - Réinitialisation par lien e-mail (POST /request-password-reset puis
     POST /reset-password/{token}), pour le cas où le mot de passe actuel
     est inconnu ou oublié.

3. Sécurité : réponse générique systématique côté request-password-reset
   -- ne révèle jamais si une adresse correspond ou non à un compte
   existant (prévention d'énumération d'utilisateurs). Fenêtre
   d'expiration volontairement plus courte (2h) que celle d'une
   confirmation d'affiliation initiale (30 jours) -- surface d'exposition
   réduite pour un mécanisme réutilisable a volonté, contrairement à une
   invitation a usage unique.

4. Table dédiée mg.password_reset_tokens (distincte de
   mg.email_confirmation_tokens) -- semantique distincte assumee des la
   conception : "confirmation d'identite initiale" et "reinitialisation
   d'un mot de passe existant" ne doivent jamais se melanger dans un
   audit, meme si le patron technique (token UUID, usage unique,
   expiration) est identique.

5. Cas particulier PROD_PENDING_ACTIVATION (sous-chantier B, ADR-001) :
   le meme mecanisme technique sert aussi de premiere activation pour un
   compte propage depuis preprod sans mot de passe -- reset_password
   transitionne alors PROD_PENDING_ACTIVATION -> AFFILIATED en plus de
   definir le mot de passe. Une seule mecanique, deux usages metier
   distincts geres par l'etat du compte au moment de l'appel.

Ce finding ne modifie aucun comportement -- il documente un mecanisme
deja construit, deja teste, deja utilise en conditions reelles, pour
qu'il apparaisse dans le registre de gouvernance au meme titre que les
autres composants du protocole d'identite.

Statut : mecanisme operationnel, documente.
    $doc$,
    $json$
{
  "type": "documentation_only",
  "trigger": "gap_identified_end_of_session_20260716",
  "built_and_tested_on": "2026-07-11",
  "first_real_world_use": "2026-07-16",
  "accessible_to": "any_affiliate_status_ACTIVE_or_AFFILIATED_no_role_restriction",
  "two_paths": ["voluntary_change_via_mon_espace_requires_current_password", "email_link_reset_for_unknown_or_forgotten_password"],
  "security_properties": {
    "generic_response_prevents_enumeration": true,
    "expiry_hours": 2,
    "comparison_expiry_initial_invitation_days": 30,
    "dedicated_token_table": "mg.password_reset_tokens"
  },
  "reused_by": "PROD_PENDING_ACTIVATION_first_activation_flow_subproject_B",
  "behavior_changed": false,
  "status": "operational_documented"
}
    $json$,
    'ORIENTED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'PASSWORD_RESET_MECHANISM_FORMALIZED';
