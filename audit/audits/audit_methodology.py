#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# audit/audits/audit_methodology.py
#
# Sprint 23 -- AUDIT OSA-2026-001
# Ajout de la section 0 : controle de duplication/cardinalite sur
# ma.indicator_values, place EN PREMIER. Reprend la logique du
# controle C0 ajoute a collectors/check_l3.py (Sprint 23).
#
# Cause racine : UNIQUE(indicator_code, country_iso3, year, layer_id,
# method_version_id) est inoperante quand method_version_id IS NULL
# (NULL <> NULL en SQL), donc ON CONFLICT DO NOTHING ne se declenche
# jamais pour ces lignes -- chaque re-execution du pipeline de
# normalisation (ma.normalize_indicator notamment) ajoute un lot
# complet supplementaire.
#
# Ce controle est place EN PREMIER car si des doublons existent, les
# sections suivantes (poids, liens, couverture...) peuvent calculer
# des resultats individuellement corrects sur des donnees dont la
# cardinalite est fausse, masquant le probleme reel (cf.
# ma.compute_pillar_score, SUM(processed_value * weight) non protege
# contre les doublons, plafonne par LEAST(1.0, ...)).

from audit.core.db import get_connection


def run():

    findings = []
    recommendations = []

    score = 100

    conn = get_connection()
    cur = conn.cursor()

    # =====================================================
    # 0. Duplication / cardinalite ma.indicator_values
    # =====================================================

    cur.execute("""
        SELECT
            indicator_code,
            layer_id,
            COUNT(*)                                              AS total_lignes,
            COUNT(*) - COUNT(DISTINCT (country_iso3, year))       AS lignes_excedentaires,
            MAX(cnt)                                              AS ratio_max
        FROM (
            SELECT
                indicator_code,
                layer_id,
                country_iso3,
                year,
                COUNT(*) AS cnt
            FROM ma.indicator_values
            GROUP BY indicator_code, layer_id, country_iso3, year
        ) sub
        GROUP BY indicator_code, layer_id
        HAVING COUNT(*) - COUNT(DISTINCT (country_iso3, year)) > 0
        ORDER BY lignes_excedentaires DESC
    """)

    duplication_rows = cur.fetchall()

    if duplication_rows:

        total_excedent = sum(row[3] for row in duplication_rows)

        findings.append(
            f"{len(duplication_rows)} (indicator_code, layer_id) avec doublons "
            f"(pays, annee) -- {total_excedent} lignes excedentaires au total"
        )

        recommendations.append(
            "Corriger method_version_id IS NULL dans ma.indicator_values "
            "(ALTER COLUMN ... SET DEFAULT 1, puis dedupliquer) avant tout "
            "recalcul de score -- cf. AUDIT OSA-2026-001"
        )

        # Detail des cas les plus severes (top 10) pour traçabilite
        for indicator_code, layer_id, total, excedent, ratio_max in duplication_rows[:10]:
            findings.append(
                f"  {indicator_code} / L{layer_id} -- {excedent} ligne(s) "
                f"excedentaire(s) (ratio max x{ratio_max}, total={total})"
            )

        # Penalite proportionnelle a l'ampleur, plafonnee pour ne pas
        # descendre le score sous 0 meme avec 224 indicateurs affectes
        # (cas observe Sprint 23). Penalite forte car ce defaut invalide
        # la fiabilite de TOUS les autres controles methodologiques.
        score -= min(60, 1 + len(duplication_rows) // 4)

    # =====================================================
    # 0b. method_version_id NULL -- mesure globale par couche
    #
    # Complementaire a 0. : meme en l'absence de doublons visibles
    # pour un indicateur donne (cas limite), un method_version_id
    # NULL signale une ligne issue d'un producteur qui ne renseigne
    # pas cette colonne -- vulnerable a une duplication future au
    # prochain re-run du pipeline.
    # =====================================================

    cur.execute("""
        SELECT
            layer_id,
            COUNT(*)                                                    AS total,
            COUNT(*) FILTER (WHERE method_version_id IS NULL)           AS nulls,
            ROUND(
                100.0 * COUNT(*) FILTER (WHERE method_version_id IS NULL)
                / GREATEST(COUNT(*), 1),
                2
            )                                                            AS pct_null
        FROM ma.indicator_values
        GROUP BY layer_id
        ORDER BY layer_id
    """)

    for layer_id, total, nulls, pct_null in cur.fetchall():

        if nulls > 0:

            findings.append(
                f"L{layer_id}: {nulls}/{total} lignes ({pct_null}%) avec "
                f"method_version_id IS NULL"
            )

            if pct_null >= 50:
                recommendations.append(
                    f"L{layer_id} : {pct_null}% de method_version_id NULL -- "
                    f"verifier les producteurs (fonctions/scripts INSERT INTO "
                    f"ma.indicator_values omettant cette colonne)"
                )
                score -= 5

    # =====================================================
    # 1. Méthodes actives
    # =====================================================

    cur.execute("""
        SELECT COUNT(*)
        FROM ma.indicator_methods
        WHERE is_active = true
    """)
    active_methods = cur.fetchone()[0]

    if active_methods == 0:
        findings.append("No active methods")
        score -= 25

    # =====================================================
    # 2. Versions multiples actives
    # =====================================================

    cur.execute("""
        SELECT method_id
        FROM ma.indicator_method_versions
        WHERE is_active = true
        GROUP BY method_id
        HAVING COUNT(*) > 1
    """)

    duplicates = cur.fetchall()

    if duplicates:
        findings.append(
            f"{len(duplicates)} methods have multiple active versions"
        )
        score -= 20

    # =====================================================
    # 3. Indicator governance
    # =====================================================

    cur.execute("""
        SELECT COUNT(*)
        FROM ma.indicator_meta
        WHERE pillar_code IS NULL
    """)

    if cur.fetchone()[0] > 0:
        findings.append("Indicators without pillar")
        score -= 10

    cur.execute("""
        SELECT COUNT(*)
        FROM ma.indicator_meta
        WHERE unit_code IS NULL
    """)

    if cur.fetchone()[0] > 0:
        findings.append("Indicators without unit")
        score -= 10

    # =====================================================
    # 4. Weight consistency
    # =====================================================

    cur.execute("""
        SELECT
            meta_code,
            ref_year,
            SUM(weight)
        FROM ma.indicator_meta_links
        WHERE is_active = true
        GROUP BY meta_code, ref_year
    """)

    for meta_code, ref_year, total_weight in cur.fetchall():

        if abs(float(total_weight) - 1.0) > 0.01:

            findings.append(
                f"{meta_code}/{ref_year} weight sum={total_weight}"
            )

            recommendations.append(
                f"Review weights for {meta_code}"
            )

            score -= 2

    # =====================================================
    # 5. Link completeness
    # =====================================================

    cur.execute("""
        SELECT
            m.pillar_code,
            m.indicator_code
        FROM ma.indicator_meta m
        LEFT JOIN ma.indicator_meta_links l
               ON l.indicator_code = m.indicator_code
              AND l.ref_year = 2024
              AND l.is_active = true
        LEFT JOIN ma.indicator_exclusions e
               ON e.indicator_code = m.indicator_code
        WHERE l.indicator_code IS NULL
          AND e.indicator_code IS NULL
          AND m.pillar_code IN ('PECO','PMON')
    """)

    missing = cur.fetchall()

    for pillar, indicator in missing:

        findings.append(
            f"{pillar}: {indicator} not linked and not excluded"
        )

        recommendations.append(
            f"Review mapping of {indicator}"
        )

        score -= 3

    # =====================================================
    # Final status
    # =====================================================

    score = max(score, 0)

    if score >= 90:
        status = "PASS"

    elif score >= 70:
        status = "REVIEW_REQUIRED"

    else:
        status = "FAIL"

    cur.close()
    conn.close()

    return {
        "module": "METHODOLOGY",
        "status": status,
        "score": score,
        "findings": findings,
        "recommendations": recommendations
    }


if __name__ == "__main__":
    print(run())
