-- ============================================================
-- Sprint 31 -- Transition doctrinale IOSA -> POA
-- GAF finding #31 POA_DOCTRINAL_TRANSITION (ORIENTED)
-- 2 juillet 2026 (correctif quoting : 3 juillet 2026)
-- Ref note de doctrine : DOCTRINE_POA_001 (docs/POA_note_doctrine.docx)
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint31_finding_31_poa_transition.sql
-- ============================================================
-- CORRECTIF (3 juillet 2026) : la version precedente utilisait
-- des apostrophes SQL doublees ('') dans un bloc de texte tres
-- long ; une des fermetures ('' au lieu de ' avant ::jsonb) a
-- ete mal doublee, ce qui empechait Postgres de refermer la
-- chaine au bon endroit (erreur "syntax error at or near
-- ORIENTED"). Cette version utilise le dollar-quoting Postgres
-- ($doc$...$doc$ et $json$...$json$) qui elimine ce risque :
-- aucune apostrophe francaise n'a besoin d'etre echappee.
-- ============================================================

BEGIN;

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
) VALUES (
    'a592c23b-423e-401f-aee4-a73fddce1129',

    'DOCTRINE-ARCH',

    'POA_DOCTRINAL_TRANSITION',

    md5('DOCTRINE-ARCH|POA_DOCTRINAL_TRANSITION|rf.indicators.indicator_group'),

    -- INFO : clarification doctrinale de presentation, aucun impact sur les scores publies
    'INFO',

    'NONE',

    0.00,

    'DOCTRINE_AND_UI',
    'rf.indicators.indicator_group + portal-v2/src/pages/Country.jsx + portal-v2/src/pages/IosaDetail.jsx + api/routers/opendata.py',

    $doc$GAF-ARCH-POA-001 -- Transition doctrinale du module IOSA vers POA (Phenomenes Observables Autonomes). Clarification de l'objet scientifique du module : un POA n'est ni un indice ni un score, mais un phenomene objectivable documente a partir de donnees primaires. Distinction actee entre identite metier (POA, visible), identite technique (indicator_group=IOSA, stable en base) et identite de presentation (fichiers/routes internes inchanges). Perimetre initial inchange : PHUM_VALUE_CAPTURE, PMIN_VALUE_LEAKAGE, PMIN_SMUGGLING_SIGNAL_RANK (cf. finding #30 IOSA_CLASS_CREATION). Ref : docs/POA_note_doctrine.docx (DOCTRINE_POA_001).$doc$,

    $json${
      "reference": "GAF-ARCH-POA-001",
      "sprint": "Sprint 31",
      "supersedes_note": "DOCTRINE_POA_001",
      "related_finding": "IOSA_CLASS_CREATION (finding #30, Sprint 27)",

      "decisions": [
        {
          "sujet": "Denomination visible (UI)",
          "decision": "IOSA -> POA (Phenomenes Observables Autonomes) sur toutes les pages, infobulles, documentation methodologique et Swagger public.",
          "impact_code": "portal-v2 (libelles) + api/routers/opendata.py (description= des routes, visible en Swagger)"
        },
        {
          "sujet": "Compteur d'observations (bug corrige)",
          "decision": "Le compteur carte pays comptait des lignes de donnees annee=2024 (Country.jsx iosaCount, filtre o.year===2024) au lieu de compter des phenomenes. PMIN_SMUGGLING_SIGNAL_RANK (serie partielle 2016-2021, aucune ligne 2024) etait donc silencieusement exclu, produisant 2 au lieu de 3. Correction actee : compter les indicator_code distincts, coherent avec la page detail (getObsStatus).",
          "impact_code": "portal-v2/src/pages/Country.jsx ligne 81"
        },
        {
          "sujet": "indicator_group = IOSA (base de donnees)",
          "decision": "Conserve tel quel comme identifiant technique stable. Aucune migration de valeur. Seul le texte de presentation (Swagger description=, portail) devient POA.",
          "impact_code": "rf.indicators.indicator_group -- AUCUN CHANGEMENT DB"
        },
        {
          "sujet": "Routes et noms de fichiers (IosaDetail.jsx, /country/:iso3/iosa)",
          "decision": "Conserves en interne (aucun gain fonctionnel a renommer, bruit Git et risque de regression). Alias de route /country/:iso3/poa ajoute en facade vers le meme composant pour coherence de l'URL visible avec le libelle affiche.",
          "impact_code": "portal-v2/src/App.jsx -- ajout alias route uniquement"
        },
        {
          "sujet": "Libelles en dur (IosaDetail.jsx)",
          "decision": "Non conforme a la doctrine \"tout en base\". Creation actee d'une table rf.poa_catalog (code FK vers rf.indicators.code, title_fr/en, description_fr/en, definition, unit, icon, display_order) pour eliminer la config JS statique. Ne duplique pas pillar_code ni value_status, deja portes par rf.indicators et ma.indicator_values.",
          "impact_code": "rf.poa_catalog (a creer) + portal-v2/src/pages/IosaDetail.jsx (a faire consommer l'API au lieu de la config statique)"
        },
        {
          "sujet": "Page A propos",
          "decision": "Restructuration actee : la page est aujourd'hui dediee exclusivement a l'ISA. Passage a une hierarchie explicite OSA -> ISA -> POA -> AMAR -> GENECO, chaque module dote d'une section propre precisant sa fonction scientifique.",
          "impact_code": "portal-v2 page A propos (FR/EN)"
        }
      ],

      "actions_sprint31": [
        "Corriger Country.jsx : compteur sur indicator_code distincts",
        "Mettre a jour description= des routes opendata.py (Swagger) : IOSA -> POA",
        "Ajouter alias de route /country/:iso3/poa dans App.jsx",
        "Creer rf.poa_catalog (DDL + seed 3 phenomenes actuels)",
        "Faire consommer IosaDetail.jsx depuis rf.poa_catalog via API (remplace config JS statique)",
        "Restructurer la page A propos autour de la hierarchie OSA/ISA/POA/AMAR/GENECO",
        "Mettre a jour AppFooter.jsx, ScoreTable.jsx, CountryISA.jsx (libelles uniquement)"
      ],

      "impact": {
        "isa_scores": "AUCUN -- clarification de presentation uniquement",
        "amar_triggers": "AUCUN",
        "geneco": "AUCUN",
        "publication": "NONE"
      }
    }$json$::jsonb,

    'ORIENTED'
) ON CONFLICT DO NOTHING;

SELECT finding_id, finding_code, severity, status
FROM ops.audit_findings
WHERE finding_code = 'POA_DOCTRINAL_TRANSITION';

COMMIT;
