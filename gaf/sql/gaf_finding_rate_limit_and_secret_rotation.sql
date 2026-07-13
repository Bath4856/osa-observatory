-- =====================================================================
-- GAF Finding -- Correction du rate-limiting global (collision de table)
-- et rotation des secrets exposes lors du debogage de la session.
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
    'INFRASTRUCTURE-SECURITY',
    'RATE_LIMIT_COLLISION_AND_SECRET_ROTATION',
    md5('INFRASTRUCTURE-SECURITY|RATE_LIMIT_COLLISION_AND_SECRET_ROTATION|session_20260713'),
    'HIGH',
    'NONE',
    0.00,
    'DEFECT_REMEDIATION',
    'mg.rate_limit_counters + api/middleware/rate_limiter.py + OSA_JWT_SECRET + API_EXPERT_KEY + DB_PASSWORD + mg.api_key_registry',
    $doc$
Deux chantiers traites le 13 juillet 2026, dans la continuite directe du
finding ADR002_E2E_VALIDATION_LATENT_DEFECTS (#36, session precedente) :
la correction du rate-limiting global de l'API, et la rotation de trois
secrets de production exposes accidentellement en clair au cours des
sessions de debogage des deux derniers jours.

--------------------------------------------------------------------
1. Rate-limiting global casse par collision de nom de table -- CORRIGE
--------------------------------------------------------------------
Constat : mg.rate_limit_counters designait en realite deux tables
distinctes selon le moment de creation. La premiere (Sprint 17, 27 mai
2026, patch_17c_rl.sql) portait le schema identifier/window_type/
counter/access_class, dediee au middleware global @app.middleware("http")
(api/middleware/rate_limiter.py), qui applique les paliers PUBLIC (60-
300 req/h)/STANDARD (500 req/j)/PREMIUM (2000 req/j)/EXPERT (illimite)
sur l'ensemble de l'API -- le socle technique du Niveau 2 "Donnees
enrichies" du modele Go-to-Market de l'OSA. La seconde (Sprint 30,
schema key_type/key_value/endpoint/count) a ete creee plus tard sous le
meme nom, pour check_rate_limit() dans api/routers/affiliation.py,
restreinte a 2 endpoints (/auth/login, /affiliation/request).
Impact : depuis que la seconde table a remplace la premiere, le
middleware global echouait silencieusement sur CHAQUE requete de l'API
(fail-open, log "Rate limit check failed"). Aucune limite PUBLIC/
STANDARD/PREMIUM/EXPERT n'etait donc appliquee en pratique sur
l'ensemble de la production, potentiellement depuis le Sprint 17 ou
depuis le remplacement de la table -- date d'origine non determinee.
Correction : nouvelle table dediee mg.api_rate_limit_counters (meme
schema Sprint 17, nom distinct), rate_limiter.py mis a jour pour la
cibler, deployee sur les trois environnements (DEV inclus, contrairement
au mecanisme de synchronisation d'identite ADR-001 qui exclut DEV --
distinction rappelee car source de confusion possible). Verification
exhaustive prealable : seuls 3 fichiers referencaient
"rate_limit_counters" dans tout le depot, aucune autre dependance
oubliee. Fonctionnement confirme en conditions reelles : headers RFC
6585 (X-RateLimit-Limit/Remaining/Reset) correctement retournes sur un
appel test, aucune erreur fail-open residuelle sur les 2 minutes suivant
le deploiement.

--------------------------------------------------------------------
2. Rotation de secrets exposes en clair pendant le debogage -- FAIT
--------------------------------------------------------------------
Constat : une commande de diagnostic (docker inspect osa-api-dev
--format '{{range .Config.Env}}...') executee pour retrouver la
configuration reseau d'un conteneur a affiche l'integralite des
variables d'environnement, secrets inclus, dans la conversation.
Quatre secrets concernes : OSA_JWT_SECRET, DB_PASSWORD, API_EXPERT_KEY,
OSA_SMTP_PASSWORD. Analyse 5W1H menee avant remediation : exposition
confinee au canal de conversation (pas de fuite publique), mais
constitue neanmoins une exposition reelle a traiter -- en particulier
OSA_JWT_SECRET, seul des quatre directement exploitable depuis
l'exterieur (signature de JWT forges pour n'importe quel role, y
compris ADMIN).
Constat aggravant : les trois secrets rotables techniquement (JWT,
EXPERT_KEY, DB_PASSWORD) etaient partages a l'identique entre les trois
environnements (DEV/PREPROD/PROD) avant cette session -- une exposition
via DEV compromettait donc PROD egalement, annulant l'interet de la
separation des environnements du point de vue securite.
Actions realisees :
  - OSA_JWT_SECRET : rotation avec generation de 3 valeurs DISTINCTES
    (une par environnement, rupture du partage constate). Invalide
    toutes les sessions actives -- sans impact reel, aucun utilisateur
    reel n'etait actif au moment de la rotation (confirme aupres du
    porteur du projet avant execution).
  - API_EXPERT_KEY : rotation complete -- nouvelle valeur par
    environnement, nouveau hash SHA-256 insere dans mg.api_key_registry
    (owner_label "OSA Admin (rotation 2026-07-13)"), ancienne cle
    ("OSA Admin Test", creee 26 mai 2026) desactivee (is_active=false,
    non supprimee -- trace d'audit conservee, FK depuis mg.otp_codes et
    mg.refresh_tokens respectees). Fait sur les trois bases (osa_db,
    osa_preprod, osa_dev).
  - DB_PASSWORD : rotation du mot de passe PostgreSQL (role postgres,
    partage par construction entre les trois bases d'un meme conteneur
    osa-db -- pas de separation par environnement possible ici).
    Sequence executee sans delai entre ALTER USER et mise a jour des
    trois .env pour minimiser la fenetre de coupure. Risque reseau
    juge faible avant execution (docker port osa-db : aucun port
    publie, base non accessible depuis l'exterieur du reseau Docker
    osa-network) mais rotation realisee neanmoins par prudence
    (defense en profondeur, secret vu une fois en clair dans un canal
    externe au systeme).
  - OSA_SMTP_PASSWORD : rotation DIFFEREE. Secret externe (compte
    Gandi), necessite une action manuelle dans l'interface
    d'administration du fournisseur, hors de portee de cette session.
    Impact juge le plus faible des quatre (envoi d'email uniquement,
    aucune authentification du systeme concernee). A traiter des que
    l'acces a l'interface Gandi est disponible.
Methode technique notable : le calcul de hash SHA-256 pour
API_EXPERT_KEY a ete fait cote shell (sha256sum) plutot que via
interpolation psql (:'var'), cette derniere ayant deja ete identifiee
comme non fonctionnelle dans cet environnement lors du finding #36 --
confirme a nouveau ici (meme erreur de syntaxe reproduite avant
contournement).
Verification post-rotation : les trois conteneurs (osa-api,
osa-api-preprod, osa-api-dev) confirmes healthy apres chaque etape de
redemarrage, connexion base testee avec succes avec le nouveau
DB_PASSWORD, authentification testee avec succes avec le nouveau
OSA_JWT_SECRET (nouveau token JWT obtenu sur preprod).
    $doc$,
    $json$
{
  "type": "defect_remediation_and_secret_rotation",
  "session_date": "2026-07-13",
  "related_finding": "ADR002_E2E_VALIDATION_LATENT_DEFECTS (finding #36)",
  "items": [
    {
      "id": 1,
      "category": "defect",
      "severity": "HIGH",
      "component": "mg.rate_limit_counters -- collision de nom, api/middleware/rate_limiter.py",
      "summary": "Middleware global de rate-limiting en fail-open silencieux sur toute requete API, duree indeterminee",
      "fix": "Table dediee mg.api_rate_limit_counters creee sur les 3 environnements, rate_limiter.py repointe, deploiement verifie (headers RFC 6585 corrects, 0 erreur fail-open residuelle)",
      "verified": true
    },
    {
      "id": 2,
      "category": "secret_exposure",
      "severity": "HIGH",
      "trigger": "docker inspect --format Config.Env sur osa-api-dev, dans le cadre d'un diagnostic reseau",
      "secrets_exposed": ["OSA_JWT_SECRET", "DB_PASSWORD", "API_EXPERT_KEY", "OSA_SMTP_PASSWORD"],
      "aggravating_factor": "Les 3 secrets rotables etaient partages a l'identique entre DEV/PREPROD/PROD avant rotation",
      "actions": [
        {"secret": "OSA_JWT_SECRET", "status": "ROTATED", "scope": "3 valeurs distinctes par environnement", "note": "Sessions actives invalidees, sans impact (aucun utilisateur reel actif)"},
        {"secret": "API_EXPERT_KEY", "status": "ROTATED", "scope": "3 valeurs distinctes, hash insere en base, ancienne cle desactivee avec tracabilite"},
        {"secret": "DB_PASSWORD", "status": "ROTATED", "scope": "1 valeur partagee (role postgres, conteneur unique osa-db)", "network_exposure": "Aucune -- docker port osa-db confirme aucun port publie"},
        {"secret": "OSA_SMTP_PASSWORD", "status": "DEFERRED", "reason": "Secret externe (Gandi), action manuelle hors de portee de cette session", "impact_if_compromised": "Envoi d'email uniquement, aucune authentification systeme"}
      ],
      "verified": true
    }
  ],
  "open_followups": [
    "Rotation de OSA_SMTP_PASSWORD des que l'acces a l'interface Gandi est disponible",
    "Considerer une politique de secrets distincts par environnement de maniere systematique (deja applique a OSA_JWT_SECRET et API_EXPERT_KEY suite a cette session, DB_PASSWORD reste partage par contrainte d'architecture -- conteneur PostgreSQL unique)"
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
WHERE finding_code = 'RATE_LIMIT_COLLISION_AND_SECRET_ROTATION';
