-- ============================================================
-- Correction du finding #40 (GOVERNANCE_BUS_IDEMPOTENCE_VERIFIED)
-- + nouveau finding : Phase 3 reellement deployee et validee
-- 19 juillet 2026
-- ============================================================
-- Ne reecrit PAS silencieusement #40 -- append a la description
-- existante, change le statut, conserve l'historique complet
-- (raw_finding original intact). Nouveau finding separe pour l'etat
-- reel constate aujourd'hui, avec preuves verifiables (event_uuid,
-- affiliate_id, timestamps reels de cette session).
--
-- A EXECUTER SUR osa_db (PROD) -- c'est la que vivent les findings
-- #38/#39/#40, verifie le 19 juillet 2026 (absents de osa_preprod).
--
-- audit_id repris de #38/#39/#40 (a592c23b-423e-401f-aee4-a73fddce1129)
-- -- NE PAS EXECUTER sans revalider qu'il s'agit toujours de
-- l'audit_id actif :
--   SELECT audit_id, audit_timestamp FROM ops.audit_runs
--   ORDER BY audit_timestamp DESC LIMIT 1;
-- ============================================================

BEGIN;

-- ── 1. Reouverture de #40 -- affirmations Phase 3/5 infirmees ────────────
UPDATE ops.audit_findings SET
    status = 'OPEN',
    description = description || $doc$

--------------------------------------------------------------------
CORRECTIF DU 19 JUILLET 2026 -- affirmations Phase 3/5 infirmees
--------------------------------------------------------------------
Ce finding affirmait phase_3_affiliation_py_adapted="done" et
phase_5_full_cycle_revalidation="done_this_session". Les deux se sont
revelees fausses lors de la reprise de session du 19 juillet 2026 :

1. affiliation.py, relu directement depuis le VPS (deux fois,
   comparaison caractere pour caractere), n'appelait toujours que
   emit_identity_event -- aucune trace d'emit_governance_event ni de
   register_domain_handler.

2. grep -rn "register_domain_handler" --include="*.py" sur l'ensemble
   du monorepo ne renvoyait que la definition du decorateur lui-meme
   (api/services/governance_events.py) -- jamais un appel. Aucun
   domaine, IDENTITY inclus, n'etait donc enregistre au moment de la
   redaction de ce finding.

3. Reproduction en direct le 19 juillet 2026 : un evenement
   AFFILIATE_CONFIRMED reel, emis en PREPROD, propage par
   governance_synchronizer.py vers POST /api/v1/sync/apply-event,
   echoue avec HTTP 422 "Domaine non pris en charge : IDENTITY" --
   exactement l'erreur que ce finding aurait du rencontrer s'il avait
   ete redige avant la veritable Phase 3.

Hypothese retenue sur l'origine de l'erreur (bonne foi, pas de
fabrication deliberee) : les 3 bugs de robustesse du synchroniseur
(boucle infinie, ordre seq, verrou claimed_at) sont vraisemblablement
reels et independants de l'existence du handler -- le testeur a tres
probablement exerce governance_synchronizer.py contre de vrais
evenements PENDING, rencontre des echecs 422 systematiques (cause
racine : Phase 3 non cablee), et corrige la robustesse du
retry/verrouillage sans identifier que la cause des echecs etait
l'absence du handler plutot qu'un defaut de queue.

Phase 3 reellement effectuee et validee de bout en bout le 19 juillet
2026 -- cf. finding ADR003_PHASE3_REAL_E2E_VALIDATION_20260719.
    $doc$
WHERE finding_id = 40;

-- ── 2. Nouveau finding -- etat reel valide le 19 juillet 2026 ────────────
INSERT INTO ops.audit_findings
    (finding_code, module, finding_hash, severity, status, description, raw_finding, audit_id)
VALUES (
    'ADR003_PHASE3_REAL_E2E_VALIDATION_20260719',
    'GOVERNANCE-EVENTS',
    md5('ADR003_PHASE3_REAL_E2E_VALIDATION_20260719'),
    'INFO',
    'RESOLVED',
    $doc$
ADR-003/004 Phase 3 (bascule du code applicatif affiliation.py vers le
bus de gouvernance generique) reellement implementee et validee de
bout en bout le 19 juillet 2026, apres decouverte que le finding #40
GOVERNANCE_BUS_IDEMPOTENCE_VERIFIED affirmait a tort cette phase
terminee (cf. correctif ajoute a la description de #40, meme date).

Modifications reelles apportees a affiliation.py :
  - import de emit_governance_event, register_domain_handler
  - handler _apply_identity_event enregistre via
    @register_domain_handler("IDENTITY"), logique dupliquee depuis
    apply_sync_event() (mutualisation stricte differee a la Phase 6,
    ADR-004 Section 5)
  - les 3 emissions dans confirm_email() basculees de
    emit_identity_event vers emit_governance_event(db, "IDENTITY",
    event_type, "AFFILIATE", affiliate_uuid, payload)
  - emit_identity_event() et apply_sync_event() conserves intacts,
    dormants -- decommissionnement reporte a la Phase 6

Deploye et verifie sur les 3 environnements (DEV puis PREPROD puis
PROD, conformement a la doctrine du projet) -- rebuild Docker complet
a chaque fois (docker rm -f + docker run, jamais docker restart).

Test end-to-end reel, compte jetable test.phase3.verif@example.com
(supprime en fin de verification, PREPROD et PROD) :
  - affiliate_id=24 (PREPROD), confirme via
    POST /confirm-email/{token}
  - evenement AFFILIATE_CONFIRMED cree dans mg.governance_events,
    domain_code=IDENTITY, object_type=AFFILIATE, target_environment=
    PROD, status=PENDING -- confirme par requete SQL directe
  - mg.identity_events verifie vide pour ce compte -- ancien mecanisme
    bien dormant, aucun effet de bord
  - governance_synchronizer.py lance manuellement : premier essai
    (avant rebuild PROD) → 422 Domaine non pris en charge, confirmant
    que #40 ne pouvait pas avoir reussi ce test avec le code alors en
    place ; second essai (apres rebuild osa-api avec Phase 3) →
    propagation reussie, statut PROPAGATED, propagated_by=
    GOVERNANCE_SYNCHRONIZER
  - compte cree cote osa_db : affiliate_id=25,
    status=PROD_PENDING_ACTIVATION, identity_uuid identique aux deux
    bases -- coherence confirmee

Cron installe : ops/install_governance_sync_cron.sh, */5 * * * *,
secret IDENTITY_SYNC_SECRET relu depuis api/.env a l'execution
(jamais fige en clair dans la ligne crontab).

Versionnement : governance_synchronizer.py, identity_synchronizer.py,
onboard_founder.py + dependances flyer, vivaient hors du monorepo
(/home/ubuntu/) depuis leur creation -- committes retroactivement
dans ops/ le 19 juillet 2026 (coherent avec run_osa_nightly.sh,
install_cron.sh deja presents ; pas scripts/, reserve au pipeline de
donnees).

Phase 6 (decommissionnement mg.identity_events, rf.identity_event_types,
emit_identity_event, apply_sync_event) non engagee par ce finding --
reste a planifier.
    $doc$,
    $json$
{
  "type": "verification_result",
  "status": "phase_3_actually_completed_and_verified",
  "test_method": "real_e2e_test_on_osa_preprod_and_osa_db_not_code_review",
  "corrects_finding": "GOVERNANCE_BUS_IDEMPOTENCE_VERIFIED (#40) -- phase_3 and phase_5 claims were false",
  "test_account": {
    "email": "test.phase3.verif@example.com",
    "preprod_affiliate_id": 24,
    "prod_affiliate_id": 25,
    "identity_uuid": "04f3ecef-828c-41c3-af82-ce1273acab18",
    "cleanup_completed": true
  },
  "code_changes": {
    "file": "api/routers/affiliation.py",
    "commit": "73cb3bd",
    "handler_registered": "IDENTITY",
    "emissions_migrated": ["AFFILIATE_CONFIRMED", "COMMITTEE_MEMBERSHIP_GRANTED", "WORKING_GROUP_ACTIVATED"],
    "legacy_mechanism": "emit_identity_event / apply_sync_event retained dormant, not deleted"
  },
  "deployment": {
    "environments": ["DEV", "PREPROD", "PROD"],
    "order": "DEV_then_PREPROD_then_PROD",
    "method": "docker rm -f + docker build + docker run, never docker restart"
  },
  "reproduction_of_false_claim": {
    "before_prod_rebuild": "HTTP 422 Domaine non pris en charge : IDENTITY",
    "after_prod_rebuild": "propagated successfully, status PROPAGATED"
  },
  "cron_installed": {
    "script": "ops/install_governance_sync_cron.sh",
    "schedule": "*/5 * * * *",
    "secret_handling": "re-read from api/.env at execution time, never embedded in crontab line"
  },
  "ops_versioning": {
    "files": ["governance_synchronizer.py", "identity_synchronizer.py", "onboard_founder.py", "flyer_template.html", "flyer_activation_template.html", "logo.png"],
    "previous_location": "/home/ubuntu/ (outside monorepo, never committed)",
    "new_location": "ops/"
  },
  "phase_6_decommissioning": "not_started"
}
    $json$,
    'a592c23b-423e-401f-aee4-a73fddce1129'
);

COMMIT;

-- Verification post-execution
SELECT finding_id, finding_code, severity, status FROM ops.audit_findings
WHERE finding_id IN (38, 39, 40) OR finding_code = 'ADR003_PHASE3_REAL_E2E_VALIDATION_20260719'
ORDER BY finding_id;
