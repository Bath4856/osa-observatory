INSERT INTO ops.audit_findings (
    audit_id, module, finding_code, finding_hash, severity,
    publication_impact, iprs_weight, object_type, object_code,
    description, raw_finding, status
) VALUES (
    'a592c23b-423e-401f-aee4-a73fddce1129',
    'DOCTRINE-ARCH',
    'IOSA_CLASS_CREATION',
    md5('DOCTRINE-ARCH|IOSA_CLASS_CREATION|rf.indicators.indicator_type'),
    'INFO',
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
    || 'PMIN_SMUGGLING_SIGNAL_RANK (106 valeurs L1, 0 L3 serie partielle). '
    || 'Chaine technique : L1 -> L3 uniquement. '
    || 'Absent de indicator_meta_links -- hors calcul ISA. '
    || 'Hors intrants directs AMAR/GENECO. '
    || 'Ref : docs/decision_doctrinale_iosa_sprint27.docx.',
    '{"reference": "GAF-ARCH-IOSA-001",
      "sprint": "Sprint 27 prepare Sprint 26",
      "decided_by": "Conseil technique OSA",
      "document_ref": "docs/decision_doctrinale_iosa_sprint27.docx",
      "doctrine": {
        "class_name": "IOSA",
        "base_principle": "P7E observation comportementale pure non comparative non imputable",
        "criteria": [
          "Source primaire unique identifiee et auditee",
          "Non comparatif inter-pays sans biais causal",
          "Non imputable absence de donnee = information souveraine",
          "Auditabilite totale source formule valeur",
          "Hors calcul ISA indicator_meta_links absent",
          "Hors intrants directs AMAR/GENECO"
        ]
      },
      "initial_perimeter": [
        {"code": "PHUM_VALUE_CAPTURE", "pillar": "PHUM", "l3_count": 810, "status": "COMPLETE"},
        {"code": "PMIN_VALUE_LEAKAGE", "pillar": "PMIN", "l3_count": 810, "status": "COMPLETE"},
        {"code": "PMIN_SMUGGLING_SIGNAL_RANK", "pillar": "PMIN", "l1_count": 106, "l3_count": 0, "status": "PARTIAL"}
      ],
      "actions_sprint27": [
        "Documenter indicator_type IOSA dans rf.indicators",
        "Creer endpoint /api/v2/sovereignty/structural-obs",
        "Calculer L3 PMIN_SMUGGLING_SIGNAL_RANK apres cache BACI",
        "Ajouter criteres IOSA dans OSA_Modele_Scientifique_ISA"
      ],
      "impact": {"isa_scores": "AUCUN", "amar_triggers": "AUCUN", "publication": "NONE"}
    }'::jsonb,
    'ORIENTED'
) ON CONFLICT DO NOTHING;

SELECT finding_id, finding_code, severity, status
FROM ops.audit_findings
WHERE finding_code = 'IOSA_CLASS_CREATION';
