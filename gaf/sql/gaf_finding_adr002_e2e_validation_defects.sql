-- =====================================================================
-- GAF Finding -- Defauts latents decouverts lors de la validation
-- end-to-end de l'ADR-002 (Architecture Readiness Review).
-- Cycle d'audit actif : a592c23b-423e-401f-aee4-a73fddce1129
-- A executer sur osa_db (prod)
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
    'ADR002_E2E_VALIDATION_LATENT_DEFECTS',
    md5('GOVERNANCE-IDENTITY|ADR002_E2E_VALIDATION_LATENT_DEFECTS|session_20260712'),
    'HIGH',
    'NONE',
    0.00,
    'DEFECT_REMEDIATION',
    'nginx:portal + mg.password_reset_tokens + identity_synchronizer.py + api/routers/affiliation.py + mg.committee_memberships/working_group_members',
    $doc$
Cinq defauts latents ont ete decouverts et corriges le 12 juillet 2026,
lors de la premiere execution reelle du cycle complet de synchronisation
d'identite prevu par l'ADR-002 (§6, demonstration du cycle Cooptation ->
Validation -> Evenement -> Synchronisation -> Compte PROD -> Activation ->
Connexion). Aucun de ces defauts n'avait ete detecte auparavant car
aucun evenement reel n'avait jamais transite de bout en bout dans le
mecanisme avant cette session.

Severite globale du finding fixee a HIGH : deux des cinq defauts (nginx,
table manquante) affectaient deja la production independamment de ce
chantier, de maniere latente, avant meme la mise en place du moteur de
synchronisation.

--------------------------------------------------------------------
1. [HIGH] Nginx prod ne proxifiait jamais /api/ vers osa-api
--------------------------------------------------------------------
Constat : /etc/nginx/sites-available/portal (site open.osa-observatory.
africa) ne contenait aucun bloc `location /api/`. Toute requete vers
/api/... tombait dans le bloc generique `location / { try_files ... }`,
qui refuse les methodes non-GET sur du contenu statique (405 Not
Allowed) et, pour des GET, aurait vraisemblablement servi index.html au
lieu d'atteindre l'API.
Impact : tout appel API externe vers le domaine public de production
etait casse, y compris potentiellement par le portail lui-meme selon
comment celui-ci construit ses URLs d'appel API.
Diagnostic : confirme par comparaison directe -- meme requete en 405 via
le domaine public, 422 (traitee normalement par FastAPI) en direct sur
127.0.0.1:8000, contournant nginx.
Correction : ajout du bloc `location /api/ { proxy_pass
http://localhost:8000; ...headers standard... }` avant le bloc
generique, via script idempotent (patch_nginx_prod_api.py), verifie par
`nginx -t` avant `systemctl reload nginx`. Non-regression confirmee
(portail toujours 200 apres reload).
Reste ouvert : verifier si le portail (React/Vite) etait deja affecte
en usage reel, ou si ses appels API passent par un autre chemin non
concerne par ce bloc -- a investiguer separement.

--------------------------------------------------------------------
2. [HIGH] mg.password_reset_tokens absente sur osa_db et osa_dev
--------------------------------------------------------------------
Constat : le script gaf/sql/create_password_reset_tokens.sql (session
du 11 juillet 2026) porte l'instruction explicite d'execution sur les
trois environnements (osa_dev, osa_preprod, osa_db) mais n'avait ete
joue que sur osa_preprod. La table n'existait ni sur osa_db (prod) ni
sur osa_dev.
Impact : POST /api/v1/affiliation/request-password-reset et
/reset-password/{token} etaient casses en production pour tout affilie
reel demandant une reinitialisation de mot de passe -- et pour tout
compte cree par propagation ADR-001 (statut PROD_PENDING_ACTIVATION,
qui utilise le meme mecanisme pour son activation initiale). Detecte ici
via une erreur 500 (sqlalchemy.exc.ProgrammingError: UndefinedTable)
lors du tout premier appel reel a POST /sync/apply-event.
Correction : script rejoue sur osa_db et osa_dev (idempotent via CREATE
TABLE IF NOT EXISTS). Schema desormais identique sur les trois
environnements, verifie par diff exhaustif des tables des schemas
mg/rf/ops (aucune divergence residuelle hors les tables mg.identity_events
et rf.identity_event_types, absentes de osa_dev par conception -- DEV
exclu du mecanisme de synchronisation, cf. ADR-001).

--------------------------------------------------------------------
3. [MEDIUM] KYC force a tort sur le parcours d'affiliation volontaire
--------------------------------------------------------------------
Constat : POST /confirm-email/{token} est partage entre deux parcours
metier distincts (cooptation PREPROD vs affiliation volontaire PROD),
mais function_title/country etaient declares obligatoires (Pydantic
Field(...)) sans distinction, contrairement a la doctrine actee
(finding #33 IDENTITY_TRACEABILITY_BY_CONSENT : PROD = communaute
ouverte, KYC non force).
Correction (ADR-002 §2, qui interdit explicitement toute branche sur
OSA_ENVIRONMENT pour cette separation) : function_title/country rendus
optionnels au niveau schema ; obligation reelle deduite de l'etat des
donnees via une nouvelle fonction _has_pending_cooptation() (existence
prealable d'un rattachement comite/groupe de travail = preuve de
cooptation = KYC obligatoire). UPDATE mg.affiliates utilise desormais
COALESCE pour ne jamais ecraser une valeur existante par NULL quand le
KYC differe (parcours volontaire).
Fichier modifie : api/routers/affiliation.py (endpoint confirm_email).

--------------------------------------------------------------------
4. [MEDIUM] Absence de contraintes d'idempotence sur deux tables
--------------------------------------------------------------------
Constat (ADR-002 §4) : mg.committee_memberships et
mg.working_group_members n'avaient aucune contrainte unique. Le motif
`ON CONFLICT DO NOTHING` deja present dans apply_sync_event() (endpoint
/sync/apply-event) n'offrait donc aucune protection reelle contre les
doublons en cas de rejeu d'evenement (retry reseau, execution manuelle
repetee).
Correction : index uniques partiels, respectant l'historique legitime
(un affilie peut quitter puis reintegrer un comite/groupe de travail) :
  CREATE UNIQUE INDEX uq_committee_membership_active
    ON mg.committee_memberships (affiliate_id, committee)
    WHERE status = 'ACTIVE';
  CREATE UNIQUE INDEX uq_working_group_member_active
    ON mg.working_group_members (affiliate_id, pillar_code)
    WHERE status = 'ACTIVE';
Un doublon preexistant a ete detecte sur osa_db lors de la creation de
la seconde contrainte (affiliate_id=8, pillar_code=PMIN) : cas
d'historique legitime (une ligne INACTIVE ancienne + une ligne ACTIVE
recente), non corrige car non fautif -- la contrainte partielle
l'accommode nativement. Appliquees et verifiees sur osa_db et
osa_preprod. Index redondant idx_memberships_active supprime sur osa_db
apres coup (couverture desormais assuree par la contrainte unique).

--------------------------------------------------------------------
5. [LOW] Interpolation de variables psql non fonctionnelle
--------------------------------------------------------------------
Constat : identity_synchronizer.py utilisait la syntaxe psql -v
nom=valeur / :'nom' pour parametrer ses UPDATE (mark_event()). Cette
interpolation s'est reveleee non fonctionnelle dans l'environnement
d'execution (docker exec -i osa-db psql ... -c), provoquant un crash
(erreur de syntaxe SQL) systematique lors de toute tentative de marquer
un evenement PROPAGATED ou FAILED -- masquant, lors du tout premier
run, l'echec reel sous-jacent (defaut #1, nginx).
Correction : echappement des litteraux SQL deplace cote Python
(fonction _sql_literal, doublement manuel des apostrophes), construction
directe de la requete sans dependre de la substitution psql. Portee
limitee au script d'administration (jamais expose publiquement, aucun
contenu de payload affilie n'y transite -- seul le message d'erreur HTTP
est concerne).
Amelioration additionnelle apportee au meme fichier (hors correction de
bug) : fetch_pending_events() reprend desormais aussi les evenements en
statut FAILED, pas seulement PENDING, pour permettre un nouveau passage
automatique apres resolution d'un incident d'infrastructure transitoire.
Limite assumee, documentee dans le fichier : aucune distinction entre
echec transitoire et echec permanent (ex. conflit 409) -- un evenement
en echec permanent sera retente indefiniment sans alerte. Dette
technique notee, non traitee dans cette session.

--------------------------------------------------------------------
Validation
--------------------------------------------------------------------
Les cinq corrections ont ete verifiees par un cycle complet reel,
execute avec un affilie de test (email jetable, comptes supprimes en
fin de session sur osa_preprod et osa_db, aucune trace residuelle) :
cooptation PREPROD -> confirmation email + KYC -> emission des
evenements AFFILIATE_CONFIRMED et WORKING_GROUP_ACTIVATED -> propagation
via identity_synchronizer.py -> creation du compte PROD (identity_uuid
stable confirme identique entre les deux environnements) -> activation
via reset-password -> connexion reussie (JWT valide, role AFFILIE,
statut AFFILIATED). Constitue la premiere validation reelle des
criteres d'acceptation ADR-002 §8 (cycle complet, §6).
    $doc$,
    $json$
{
  "type": "defect_remediation",
  "discovered_during": "ADR-002_end_to_end_validation",
  "session_date": "2026-07-12",
  "defects": [
    {
      "id": 1,
      "severity": "HIGH",
      "component": "nginx (portal, open.osa-observatory.africa)",
      "summary": "Aucun bloc location /api/ -- tout appel API externe vers PROD bloque (405)",
      "fix": "Bloc proxy_pass ajoute via patch_nginx_prod_api.py, valide par nginx -t, reload sans interruption",
      "verified": true
    },
    {
      "id": 2,
      "severity": "HIGH",
      "component": "mg.password_reset_tokens (osa_db, osa_dev)",
      "summary": "Table absente sur 2 des 3 environnements malgre instruction d'execution explicite dans le script source",
      "fix": "Script create_password_reset_tokens.sql rejoue sur osa_db et osa_dev (idempotent)",
      "verified": true
    },
    {
      "id": 3,
      "severity": "MEDIUM",
      "component": "api/routers/affiliation.py -- confirm_email",
      "summary": "KYC obligatoire pour tous, y compris affiliation volontaire PROD, en contradiction avec finding #33",
      "fix": "Obligation deduite de l'etat des donnees (_has_pending_cooptation), jamais de OSA_ENVIRONMENT (conforme ADR-002 §2)",
      "verified": true
    },
    {
      "id": 4,
      "severity": "MEDIUM",
      "component": "mg.committee_memberships, mg.working_group_members",
      "summary": "Aucune contrainte unique -- ON CONFLICT DO NOTHING sans protection reelle contre les doublons",
      "fix": "Index uniques partiels WHERE status = 'ACTIVE', appliques sur osa_db et osa_preprod",
      "verified": true
    },
    {
      "id": 5,
      "severity": "LOW",
      "component": "identity_synchronizer.py -- mark_event",
      "summary": "Interpolation psql -v/:'var' non fonctionnelle dans cet environnement -- crash systematique",
      "fix": "Echappement SQL deplace cote Python (_sql_literal)",
      "verified": true,
      "additional_change": "fetch_pending_events() reprend aussi les evenements FAILED, pas seulement PENDING",
      "known_debt": "Pas de distinction transitoire/permanent -- retry indefini sans alerte pour echec permanent"
    }
  ],
  "e2e_validation": {
    "performed": true,
    "test_account_email": "test.adr002.cycle@example.com",
    "cleanup_completed": true,
    "adr002_section6_criteria": "satisfied"
  },
  "open_followups": [
    "Verifier si le portail React/Vite prod etait affecte en usage reel par le defaut nginx #1",
    "Rate_limit_counters : divergence de schema entre code (key_type/key_value/count) et osa_db (identifier/window_type/counter), absorbee en fail-open -- non investiguee dans cette session",
    "Changer le mot de passe du compte admin preprod (theophile.bakang@gmail.com, id=3) -- expose en clair a plusieurs reprises pendant cette session de debogage"
  ]
}
    $json$,
    'RESOLVED'
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

-- Verification post-execution
SELECT finding_id, finding_code, module, severity, status
FROM ops.audit_findings
WHERE finding_code = 'ADR002_E2E_VALIDATION_LATENT_DEFECTS';
