-- ============================================================
-- GAF Finding : SWOT_SIGNAL_AVAILABILITY
-- Reference : GAF-P7I-WKN-SEMANTICS-001
-- Sprint 26 -- Audit chaîne SWOT/P7I
-- Date d'émission : 23 juin 2026
-- Validé par : Conseil technique OSA
-- ============================================================
-- INSTRUCTIONS D'EXÉCUTION
-- docker exec -i osa-db psql -U postgres -d osa_db < gaf_finding_p7i_wkn_semantics.sql
--
-- VÉRIFICATION POST-EXÉCUTION :
--   SELECT finding_id, finding_code, status
--   FROM ops.audit_findings
--   WHERE finding_code = 'SWOT_SIGNAL_AVAILABILITY'
--   ORDER BY finding_id DESC LIMIT 1;
--
-- NOTE : audit_id = a592c23b-423e-401f-aee4-a73fddce1129
--   (cycle d'audit actif — même référence que findings #20-23)
--   Si le cycle a été renouvelé depuis Sprint 25, substituer
--   l'audit_id actif avant exécution.
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

    -- ── AUDIT RUN ─────────────────────────────────────────────
    'a592c23b-423e-401f-aee4-a73fddce1129',

    -- ── MODULE ────────────────────────────────────────────────
    'P7I-SWOT',

    -- ── CODE ──────────────────────────────────────────────────
    'SWOT_SIGNAL_AVAILABILITY',

    -- ── HASH (SHA-256 : module|code|object_code) ──────────────
    -- echo -n 'P7I-WKN-SEMANTICS|SWOT_SIGNAL_AVAILABILITY|ma.computed_values' | sha256sum
    '0e0d6b2416524ab3088e041c57b607d683fa824376ad73adace066cde3a77849',

    -- ── SÉVÉRITÉ ──────────────────────────────────────────────
    -- MEDIUM : défaut sémantique sans impact sur les scores
    -- publiés, mais avec impact sur l'interprétation analytique
    -- et la traçabilité scientifique.
    'MEDIUM',

    -- ── IMPACT PUBLICATION ────────────────────────────────────
    -- Aucun impact sur les résultats publiés 2020-2024.
    -- Les scores ISA, AMAR (18 triggers), GENECO ne sont pas
    -- modifiés. La distinction porte sur la couche analytique.
    'NONE',

    -- ── POIDS IPRS ────────────────────────────────────────────
    -- Défaut de traçabilité analytique, non de calcul.
    0.00,

    -- ── OBJET ─────────────────────────────────────────────────
    'VIEW_CHAIN',
    'ma.computed_values → ma.v_p7i_risk_source',

    -- ── DESCRIPTION ───────────────────────────────────────────
    'GAF-P7I-WKN-SEMANTICS-001 -- Perte de la distinction semantique '
    || 'entre faiblesse observee nulle (WKN = 0, confidence > 0) '
    || 'et faiblesse non observee (WKN = NULL, confidence = 0) '
    || 'dans la chaine de transformation SWOT/P7I.'
    || E'\n\n'
    || 'ORIGINE : ma.computed_values (L1 collecte). '
    || 'La valeur WKN_PENV de SDN 2024 est absente en L1 '
    || '(value = NULL, confidence = 0.000). '
    || 'Ce NULL est correctement propage par v_p7f_computed_swot_source '
    || 'mais absorbe de maniere silencieuse par un COALESCE(wkn.swot_value, 0) '
    || 'dans v_isa_strategic_diagnostic_engine, '
    || 'produisant weakness_score = 0.000 dans v_p7i_risk_source. '
    || E'\n\n'
    || 'CONSEQUENCE : deux situations indiscernables en aval : '
    || '(1) WKN observe et evalue a zero (faiblesse negligeable) ; '
    || '(2) WKN non observe, absence de donnee (faiblesse inconnue). '
    || E'\n\n'
    || 'PERIMETRE AFFECTE : analyse strategique, travaux GENECO, '
    || 'audits scientifiques, interpretations TRIGGER_CRITICAL '
    || '(classe conditionnee par WKN >= 0.70). '
    || E'\n\n'
    || 'MOTEUR AMAR NON AFFECTE FONCTIONNELLEMENT : '
    || 'les 18 triggers historiques 2020-2024 sont inchanges. '
    || 'SDN 2024 PENV produit correctement TRIGGER_EXCEPTIONAL '
    || '(THR = 1.000 >= 0.40, independamment de WKN). '
    || E'\n\n'
    || 'DECISION CONSEIL TECHNIQUE : preservation explicite '
    || 'de la disponibilite du signal WKN via attribut data_availability '
    || 'dans ma.computed_values. Aucun recalcul des scores existants.',

    -- ── RAW_FINDING ───────────────────────────────────────────
    '{
      "reference": "GAF-P7I-WKN-SEMANTICS-001",
      "sprint": "Sprint 26",
      "detected_at": "2026-06-23",
      "validated_by": "Conseil technique OSA",

      "chain_audit": {
        "origin": {
          "table": "ma.computed_values",
          "layer": "L1",
          "case": "SDN | 2024 | WKN_PENV",
          "value": null,
          "confidence": 0.000,
          "semantic": "valeur absente — non observee"
        },
        "propagation": {
          "view": "ma.v_p7f_computed_swot_source",
          "behavior": "NULL propage correctement",
          "issue": "aucun"
        },
        "transformation": {
          "view": "ma.v_isa_strategic_diagnostic_engine",
          "operation": "COALESCE(wkn.swot_value, 0)",
          "behavior": "NULL absorbe silencieusement",
          "issue": "POINT DE TRANSFORMATION FAUTIF — perte semantique"
        },
        "output": {
          "view": "ma.v_p7i_risk_source",
          "weakness_score": 0.000,
          "semantic_error": "faiblesse inconnue apparait comme faiblesse nulle observee"
        }
      },

      "semantic_confusion": {
        "case_1": {
          "label": "Faiblesse observee nulle",
          "wkn_value": 0.000,
          "confidence": "> 0",
          "interpretation": "La faiblesse a ete evaluee et jugee negligeable"
        },
        "case_2": {
          "label": "Faiblesse non observee",
          "wkn_value": null,
          "confidence": 0.000,
          "interpretation": "La faiblesse na pas pu etre observee ou calculee"
        },
        "post_coalesce": {
          "weakness_score_case_1": 0.000,
          "weakness_score_case_2": 0.000,
          "indiscernables": true
        }
      },

      "amar_impact": {
        "functional_impact": "AUCUN",
        "triggers_affected": 0,
        "triggers_total": 18,
        "sdn_2024_penv": {
          "thr_score": 1.000,
          "wkn_source": null,
          "wkn_post_coalesce": 0.000,
          "trigger_class": "TRIGGER_EXCEPTIONAL",
          "trigger_correct": true,
          "rationale": "TRIGGER_EXCEPTIONAL conditionne par THR >= 0.40 uniquement — independant de WKN"
        },
        "trigger_critical_risk": {
          "condition": "THR >= 0.20 ET WKN >= 0.700",
          "risk": "Un pays avec WKN NULL (inconnu) ne peut jamais atteindre TRIGGER_CRITICAL — classe de vigilance renforcee inaccessible pour des donnees manquantes"
        }
      },

      "implementation": {
        "approach": "Preservation semantique a la source — sans recalcul",
        "primary_action": {
          "table": "ma.computed_values",
          "column_to_add": "data_availability",
          "type": "VARCHAR(20)",
          "constraint": "CHECK (data_availability IN (''OBSERVED'', ''ESTIMATED'', ''MISSING''))",
          "default": "OBSERVED",
          "mapping": {
            "OBSERVED": "value IS NOT NULL AND confidence > 0",
            "ESTIMATED": "value provient de MICE imputation (L2)",
            "MISSING": "value IS NULL OR confidence = 0"
          }
        },
        "monitoring_view": {
          "view": "ops.v_data_availability_audit",
          "purpose": "Vue de surveillance croisant WKN MISSING avec triggers actifs",
          "key_alert": "WKN MISSING sur pays portant un trigger EXCEPTIONAL ou CRITICAL"
        },
        "no_impact_on": [
          "scores ISA 2020-2024",
          "18 triggers AMAR historiques",
          "resultats GENECO",
          "resultats publies portal"
        ]
      },

      "architectural_rule": {
        "code": "GAF-ARCH-001",
        "label": "No silent COALESCE on analytical views",
        "rule": "Toute operation COALESCE(indicator_value, 0) dans une vue analytique doit etre accompagnee dun attribut _observed = (value IS NOT NULL AND confidence > 0)",
        "scope": "Toutes les vues ma.v_isa_* et ma.v_p7*",
        "status": "PROPOSED — a valider Conseil technique"
      },

      "visibility_improvement": {
        "diagnosis": "Defaut enfoui a 3 niveaux : origine L1 (absence), propagation silencieuse (vue intermediaire), transformation opaque (COALESCE). Invisible en Sprint 25 car detecte uniquement en aval sur weakness_score = 0.",
        "mechanisms": [
          "data_availability dans ma.computed_values — survit a tous les COALESCE",
          "ops.v_data_availability_audit — vue de monitoring interrogeable a chaque sprint",
          "GAF-ARCH-001 — regle preventive pour futurs developpements"
        ]
      }
    }'::jsonb,

    -- ── STATUT ────────────────────────────────────────────────
    -- ORIENTED : constat établi, décision validée par le Conseil
    -- technique, implémentation définie, aucune décision ouverte.
    'ORIENTED'

)
RETURNING finding_id, finding_code, status;

-- ============================================================
-- VÉRIFICATION
-- ============================================================
SELECT
    finding_id,
    finding_code,
    severity,
    status,
    detected_at::date AS date_finding,
    LEFT(description, 80) AS description_debut
FROM ops.audit_findings
WHERE finding_code = 'SWOT_SIGNAL_AVAILABILITY'
ORDER BY finding_id DESC
LIMIT 1;

COMMIT;
