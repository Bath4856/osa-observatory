-- ============================================================
-- GAF Finding #30 -- IOSA_CLASS_CREATION
-- Institution de la classe IOSA (Indicateurs d'Observation
-- Souveraine Autonome) dans l'architecture OSA
-- Sprint 27 (prepare en Sprint 26) -- 23 juin 2026
-- Conseil technique OSA
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint27_finding_30_iosa_class.sql
-- ============================================================

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

    'IOSA_CLASS_CREATION',

    md5('DOCTRINE-ARCH|IOSA_CLASS_CREATION|rf.indicators.indicator_type'),

    -- INFO : decision architecturale sans impact sur les scores publies
    'INFO',

    -- Aucun impact sur les scores ISA publies
    'NONE',

    0.00,

    'SCHEMA_AND_DOCTRINE',
    'rf.indicators + ma.indicator_values',

    'GAF-ARCH-IOSA-001 -- Institution de la classe IOSA : '
    || 'Indicateurs d''Observation Souveraine Autonome. '
    || 'Classe doctrinale pour indicateurs comportementaux observables '
    || 'non comparatifs inter-pays, non imputables, auditables. '
    || 'Perimetre initial : PHUM_VALUE_CAPTURE (810 valeurs L3), '
    || 'PMIN_VALUE_LEAKAGE (810 valeurs L3), '
    || 'PMIN_SMUGGLING_SIGNAL_RANK (106 valeurs L1, 0 L3 -- serie partielle). '
    || 'Chaine technique : L1 -> L3 uniquement. '
    || 'Absent de indicator_meta_links -- hors calcul ISA. '
    || 'Hors intrants directs AMAR/GENECO. '
    || 'Ref : decision_doctrinale_iosa_sprint27.docx.',

    '{
      "reference": "GAF-ARCH-IOSA-001",
      "sprint": "Sprint 27 (prepare Sprint 26)",
      "detected_at": "2026-06-23",
      "decided_by": "Conseil technique OSA",
      "document_ref": "docs/decision_doctrinale_iosa_sprint27.docx",

      "doctrine": {
        "class_name": "IOSA",
        "full_name": "Indicateur d''Observation Souveraine Autonome",
        "base_principle": "P7E -- observation comportementale pure, non comparative, non imputable",
        "criteria": [
          "Source primaire unique identifiee et auditee",
          "Non comparatif inter-pays sans biais causal",
          "Non imputable -- absence de donnee = information souveraine",
          "Auditabilite totale : source -> formule -> valeur",
          "Hors calcul ISA (indicator_meta_links absent)",
          "Hors intrants directs AMAR/GENECO"
        ]
      },

      "initial_perimeter": [
        {
          "code": "PHUM_VALUE_CAPTURE",
          "pillar": "PHUM",
          "source": "WB SH.MED.PHYS.ZS + SE.TER.ENRR",
          "l3_count": 810,
          "coverage": "54 pays 2010-2024",
          "status": "COMPLETE"
        },
        {
          "code": "PMIN_VALUE_LEAKAGE",
          "pillar": "PMIN",
          "source": "CEPII BACI HS92 (HS26+27+71)",
          "l3_count": 810,
          "coverage": "54 pays 2010-2024",
          "status": "COMPLETE"
        },
        {
          "code": "PMIN_SMUGGLING_SIGNAL_RANK",
          "pillar": "PMIN",
          "source": "BACI x USGS MIN_PRD_*",
          "l1_count": 106,
          "l3_count": 0,
          "coverage": "37 pays 2016-2021",
          "status": "PARTIAL -- extension 2022-2024 conditionnee au cache BACI"
        }
      ],

      "technical_chain": {
        "L1": "collect.raw_data -- valeur brute source unique",
        "L2": "ABSENT -- non-imputation doctrinale",
        "L3": "ma.indicator_values -- normalisation interne pays (benchmark propre)",
        "indicator_meta_links": "ABSENT -- hors calcul ISA",
        "exposition": "Endpoint dedie /api/v2/sovereignty/structural-obs ou API premium"
      },

      "actions_sprint27": [
        "Documenter indicator_type IOSA dans rf.indicators pour les 3 indicateurs",
        "Mettre a jour description rf.indicators avec mention classe IOSA",
        "Creer endpoint /api/v2/sovereignty/structural-obs",
        "Calculer L3 PMIN_SMUGGLING_SIGNAL_RANK (fetcher_baci_mirror.py requis)",
        "Ajouter criteres IOSA dans OSA_Modele_Scientifique_ISA"
      ],

      "future_candidates": [
        "MIN_LEAKAGE_RISK (181 valeurs partielles en base)",
        "Indicateurs flux financiers illicites si source primaire disponible",
        "Indicateurs dependance technologique sectorielle",
        "Signaux capture etatique non perceptuels"
      ],

      "impact": {
        "isa_scores": "AUCUN -- indicateurs hors calcul ISA",
        "amar_triggers": "AUCUN",
        "geneco": "AUCUN -- usage contextuel analytique uniquement",
        "publication": "NONE"
      }
    }''::jsonb,

    'ORIENTED'
) ON CONFLICT DO NOTHING;

SELECT finding_id, finding_code, severity, status
FROM ops.audit_findings
WHERE finding_code = 'IOSA_CLASS_CREATION';
