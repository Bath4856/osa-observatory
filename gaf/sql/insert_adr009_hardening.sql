-- ============================================================
-- ADR-009 -- Durcissement pre-onboarding reel
-- + finding GAF associe
-- 20 juillet 2026
-- ============================================================
-- A executer sur osa_db (PROD) -- meme base que le registre
-- rf.adr_registry et les findings #38/#39/#40/#49 deja utilises
-- cette session.
--
-- Verifier avant execution que ADR-009 est toujours libre :
--   SELECT adr_code FROM rf.adr_registry WHERE adr_code = 'ADR-009';
--   (doit retourner 0 ligne)
-- Et que l'audit_id utilise ci-dessous est toujours l'actif :
--   SELECT audit_id, audit_timestamp FROM ops.audit_runs
--   ORDER BY audit_timestamp DESC LIMIT 1;
-- ============================================================

BEGIN;

INSERT INTO rf.adr_registry
    (adr_code, title_fr, title_en, status, document_path, decided_on, description, needs_completion)
VALUES (
    'ADR-009',
    'Durcissement pré-onboarding réel',
    'Real onboarding hardening',
    'ACCEPTED',
    'gaf/docs/ADR/ADR-009_durcissement_pre_onboarding_reel.md',
    '2026-07-20',
    $doc$
Decision actee : la validation des donnees 2025 sera realisee par l'equipe
fondatrice de 24 a 50 personnes, constituee progressivement (sans seuil ni
date fixe), en PRODUCTION REELLE, sans retour en arriere -- avant la
consolidation officielle des equipes (fevrier/mars 2027) et le premier cycle
de validation officiel (aout 2027, donnees 2026, rf.publication_policy).
Cette validation 2025 n'est pas "officielle" au sens de la doctrine de
publication existante.

Point de doctrine confirme (coherent avec ADR-001, ADR-003/004) : toute
decision de cooptation (comite ou groupe de travail) nait en PREPROD,
environnement de reference organisationnelle, puis se synchronise vers PROD.
Les affilies volontaires (hors cooptation, /register en PROD) restent seuls
a s'inscrire directement en PROD ; tous les comites et groupes de travail
sont decides en PREPROD.

Consequence directe : l'irreversibilite de cette validation eleve au rang de
prerequis bloquant tout ce qui protege l'integrite et la securite des
comptes reels crees a partir de maintenant -- avant meme la publication
institutionnelle de 2027, echeance de reference jusqu'ici pour ce type de
durcissement.

Socle de durcissement (statut au 20 juillet 2026) :
1. Rotation IDENTITY_SYNC_SECRET (expose en clair en session de travail) --
   FAIT, nouvelle valeur generee, deployee PROD, verifiee fonctionnelle.
2. Rotation OSA_SMTP_PASSWORD (expose en clair en session de travail) --
   FAIT, change sur Gandi, teste reellement, deploye sur les 3 environnements.
3. Nettoyage compte de test residuel "Test FlyerFinal" (mg.affiliates, PROD)
   -- FAIT.
4. /terms (CGU) -- EXPLICITEMENT REPORTE. Un brouillon existe (docs/AKB et
   session du 19 juillet 2026) mais couvre uniquement le perimetre
   affiliation/E-Participation ; OIM et OSOA n'ont pas encore fourni leur
   volet contractuel (contrats, KYC clients externes, conditions
   commerciales OSOA). Publication prematuree jugee incomplete -- reporte
   jusqu'a mise en oeuvre d'OSOA, choix assume, pas un oubli. Ne bloque pas
   l'onboarding malgre son statut generique d'item de durcissement.
5. gaf/GAF_DEPLOY_PROCEDURE.sh -- mot de passe DB en clair (Sprint 24,
   ancien) -- OUVERT, a verifier si deja couvert par une rotation anterieure.
6. Premier onboarding reel isole avant scale a 24-50 -- RECOMMANDE, non
   tranche -- meme logique que DEV->PREPROD->PROD appliquee au pipeline
   humain.

Consequences : Phase 6 ADR-003 (decommission mg.identity_events) reste hors
scope, reportee apres preuve du bus generique en conditions reelles. Toute
nouvelle exposition de secret en clair doit desormais declencher une
rotation immediate sans attendre un cycle planifie -- tolerance au risque
reduite du fait de la production reelle imminente.
    $doc$,
    false
);

INSERT INTO ops.audit_findings
    (finding_code, module, finding_hash, severity, status, description, raw_finding, audit_id)
VALUES (
    'ADR009_HARDENING_PRE_ONBOARDING_20260720',
    'GOVERNANCE-EVENTS',
    md5('ADR009_HARDENING_PRE_ONBOARDING_20260720'),
    'HIGH',
    'RESOLVED',
    $doc$
Documente les actions de durcissement realisees le 19-20 juillet 2026 en
consequence directe de la decision ADR-009 (validation 2025 par l'equipe
24-50 en production reelle, sans retour en arriere).

Actions realisees et verifiees :
1. IDENTITY_SYNC_SECRET rote -- ancienne valeur invalidee, nouvelle deployee
   sur osa-api (PROD), testee (403 attendu sans secret sur
   /api/v1/sync/apply-event, confirme).
2. OSA_SMTP_PASSWORD rote -- change reellement sur Gandi (admin.gandi.net,
   boite noreply@osa-observatory.africa), nouvelle valeur testee par
   authentification SMTP reelle (smtplib, SUCCES confirme) avant deploiement
   sur les 3 fichiers api/.env* et redemarrage propre des 3 conteneurs
   (docker rm -f + docker run, jamais docker restart).
3. Compte de test "Test FlyerFinal" (mg.affiliates.id=24, PROD,
   email theo.bakang@orange.fr, statut PROD_PENDING_ACTIVATION depuis le 16
   juillet 2026) supprime avec ses dependances
   (password_reset_tokens, working_group_members).

Point ouvert transporte hors de ce finding : gaf/GAF_DEPLOY_PROCEDURE.sh
(Sprint 24, 17 juin 2026) contient un mot de passe DB en clair
(PGPASSWORD=Il1tRBwubTkPd8jd) -- statut de rotation non verifie, a traiter
separement.

/terms (CGU) explicitement exclu du perimetre de ce finding -- decision
assumee de le reporter apres mise en oeuvre d'OSOA (cf. ADR-009,
description).
    $doc$,
    $json$
{
  "type": "hardening_actions",
  "status": "actions_completed_and_verified",
  "parent_decision": "ADR-009",
  "actions": [
    {
      "id": 1,
      "title": "Rotation IDENTITY_SYNC_SECRET",
      "verified_by": "HTTP 403 on /api/v1/sync/apply-event without secret",
      "deployed_to": ["PROD"]
    },
    {
      "id": 2,
      "title": "Rotation OSA_SMTP_PASSWORD",
      "verified_by": "real SMTP auth test via smtplib against mail.gandi.net",
      "deployed_to": ["PROD", "PREPROD", "DEV"]
    },
    {
      "id": 3,
      "title": "Cleanup test account Test FlyerFinal",
      "affiliate_id": 24,
      "environment": "PROD",
      "email": "theo.bakang@orange.fr"
    }
  ],
  "explicitly_out_of_scope": ["/terms CGU -- deferred until OSOA implementation", "GAF_DEPLOY_PROCEDURE.sh DB password -- open, not verified"],
  "remaining_open_items": ["gaf/GAF_DEPLOY_PROCEDURE.sh plaintext DB password", "first isolated real onboarding before scaling to 24-50"]
}
    $json$,
    'a592c23b-423e-401f-aee4-a73fddce1129'
);

COMMIT;

-- Verification post-execution
SELECT adr_code, status, decided_on FROM rf.adr_registry WHERE adr_code = 'ADR-009';
SELECT finding_id, finding_code, severity, status FROM ops.audit_findings
WHERE finding_code = 'ADR009_HARDENING_PRE_ONBOARDING_20260720';
