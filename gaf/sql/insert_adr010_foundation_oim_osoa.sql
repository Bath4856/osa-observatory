-- ============================================================
-- ADR-010 -- Cadre institutionnel Fondation BAKAÑ / OIM / OSOA
-- + finding GAF associe
-- 20 juillet 2026
-- ============================================================
-- A executer sur osa_db (PROD).
--
-- Verifier avant execution que ADR-010 est toujours libre :
--   SELECT adr_code FROM rf.adr_registry WHERE adr_code = 'ADR-010';
--   (doit retourner 0 ligne)
-- Et que l'audit_id utilise ci-dessous est toujours l'actif :
--   SELECT audit_id, audit_timestamp FROM ops.audit_runs
--   ORDER BY audit_timestamp DESC LIMIT 1;
-- ============================================================

BEGIN;

INSERT INTO rf.adr_registry
    (adr_code, title_fr, title_en, status, document_path, decided_on, description, needs_completion)
VALUES (
    'ADR-010',
    'Cadre institutionnel Fondation BAKAÑ / OIM / OSOA',
    'BAKAÑ Foundation / OIM / OSOA institutional framing',
    'ACCEPTED',
    'gaf/docs/ADR/ADR-010_fondation_oim_osoa_framing.md',
    '2026-07-20',
    $doc$
Decision actee suite a la presentation d'un projet de statuts institutionnels
de niveau fondateur (Fondation BAKAN, inspire CERN/Wikimedia/Linux
Foundation) en amont de la mise en oeuvre operationnelle d'OSOA.

1. La Fondation BAKAN, creee en Republique du Cameroun avant le lancement
institutionnel de septembre 2027, sera la personne morale signataire des
contrats OSOA (osoa.contracts). Consequence sur le sequencement : la
construction et le test du pipeline OSOA (API, portail, traitement
documentaire) ne sont PAS bloques par ce calendrier -- seule l'execution
reelle d'un contrat (signature engageant une personne morale) l'est.
"Rendre utilisable OSOA" reste donc la prochaine priorite operationnelle,
non retardee. Le reste des preoccupations institutionnelles (statuts
complets, gouvernance en colleges, garanties d'independance) sera traite au
cas par cas, objectif 90-100% du calendrier pret au lancement de septembre
2027.

2. Taxonomie documentaire OSOA actee : AMI/AO/AOI (ouverts, portes par le
Collège/Comite Technique) vs DP -- Demande de Proposition (reservee aux
cabinets, osoa.clients, KYC propre distinct de mg.affiliates). Traitement
documentaire externe assure par une IA documentaire utilisant les memes
outils d'analyse qu'OIM -- coherent avec la capitalisation croisee deja
verifiee en session (chemin interne et externe convergent vers le meme
mg.intervention_patterns). Reserve actee : la valorisation de ce traitement
comme signal PNUM pour le pays hote n'est recevable que sur des faits
observables et mesurables (volume, latence, taux d'automatisation reel),
jamais sur une declaration d'intention -- coherence stricte P7E.

3. Cadre probabiliste formalise : POA/AMAR/GENECO (Produit 2, moniteurs
sectoriels) DETECTENT des signaux -- ne modifient jamais directement le
calcul ISA ; un signal non traite se traduira, s'il persiste, en
degradation observee lors d'un cycle de collecte futur. OIM et OSOA
RECOMMANDENT des interventions -- ne modifient jamais directement le calcul
ISA non plus ; seule une amelioration reellement collectee lors d'un cycle
futur fait remonter l'ISA. Garde-fou acte, symetrique a celui deja en place
pour AMAR ("outil d'aide a l'analyse, ne remplace pas les evaluations des
autorites competentes") : toute surface publique exposant des sorties
OIM/OSOA doit porter un disclaimer equivalent -- non fait a ce jour, a
integrer lors de la construction des API/portail correspondantes.

4. Denomination formelle : OIM et OSOA reunis sont designes "Moteur de
genie scientifique" de l'OSA -- fixee pour prevenir la derive de nommage
deja connue avec la paire OSOA/OASA (jamais tranchee dans le document
source d'origine, cf. ADR-008).

Conclusion : aucun changement de priorite operationnelle. Le projet de
statuts complet (Titres I a XVI, Constitution doctrinale) est note comme
reference a moyen terme, non engage formellement par le present ADR -- seul
le role de signataire contractuel de la Fondation est acte ici.
    $doc$,
    false
);

INSERT INTO ops.audit_findings
    (finding_code, module, finding_hash, severity, status, description, raw_finding, audit_id)
VALUES (
    'ADR010_FOUNDATION_OIM_OSOA_FRAMING_20260720',
    'GOVERNANCE-ENGINEERING',
    md5('ADR010_FOUNDATION_OIM_OSOA_FRAMING_20260720'),
    'MEDIUM',
    'RESOLVED',
    $doc$
Documente et trace la decision ADR-010 (cadre institutionnel Fondation
BAKAN / OIM / OSOA) suite a la presentation d'un projet de statuts
fondateurs en reunion le 20 juillet 2026.

Points traces :
1. Role de la Fondation BAKAN (creation Cameroun avant septembre 2027)
   comme future signataire des contrats osoa.contracts -- ne bloque pas la
   construction/test du pipeline OSOA, seulement son execution contractuelle
   reelle.
2. Taxonomie documentaire AMI/AO/AOI (ouverts) vs DP (osoa.clients) et
   principe de traitement par IA documentaire partageant les outils
   d'analyse avec OIM.
3. Cadre probabiliste POA/AMAR/GENECO (detection, tire vers 0) vs OIM/OSOA
   (recommandation, tire vers 1) -- formalise avec la reserve qu'aucun des
   deux ne modifie directement le calcul ISA, seule une donnee reellement
   collectee le fait. Disclaimer symetrique a celui d'AMAR requis pour
   OIM/OSOA -- reste a rediger et integrer, non fait a ce jour.
4. Denomination "Moteur de genie scientifique" fixee pour OIM+OSOA reunis.

Point ouvert transporte hors de ce finding : le disclaimer standard
OIM/OSOA n'est pas encore redige ni integre -- a faire lors de la
construction des API/portail OSOA (chantier "rendre utilisable OSOA",
toujours prioritaire et non retarde par cette decision).
    $doc$,
    $json$
{
  "type": "institutional_framing",
  "status": "decisions_traced_not_yet_implemented",
  "parent_decision": "ADR-010",
  "points_traced": [
    "foundation_as_contract_signatory",
    "osoa_document_taxonomy_ami_ao_aoi_dp",
    "probabilistic_framing_detection_vs_recommendation",
    "moteur_de_genie_scientifique_naming"
  ],
  "sequencing_impact": "none -- rendre utilisable OSOA reste prioritaire, non retarde par le calendrier de la Fondation",
  "remaining_open_items": ["disclaimer standard OIM/OSOA a rediger et integrer lors de la construction API/portail OSOA"]
}
    $json$,
    'a592c23b-423e-401f-aee4-a73fddce1129'
);

COMMIT;

-- Verification post-execution
SELECT adr_code, status, decided_on FROM rf.adr_registry WHERE adr_code = 'ADR-010';
SELECT finding_id, finding_code, severity, status FROM ops.audit_findings
WHERE finding_code = 'ADR010_FOUNDATION_OIM_OSOA_FRAMING_20260720';
