"""
============================================================
OSA / ISA OBSERVATORY
collectors/imputer.py -- Module d'imputation L2
============================================================
Insere une couche intermediaire L2 entre les donnees brutes
L1 et la normalisation L3.

3 categories de nulls identifies sur la base OSA :

  A -- Nulls periodiques (ECO_LOG, HUM_GEN)
       Source publiee tous les 2 ans -> annees impaires vides
       Solution : interpolation lineaire entre annees connues

  B -- Nulls epars (HUM_LIT, MIL_PER, MON_STB)
       Recensements irreguliers -> valeurs partielles par pays
       Solution : interpolation lineaire intra-pays +
                  forward/backward fill aux extremites +
                  KNN entre pays similaires si aucune valeur

  C -- Nulls massifs par source (MON_EXT < 20% couverture)
       Source insuffisante -> imputation impossible
       Solution : flaguer + recommander changement de source

Usage :
  python collectors/imputer.py --dry-run
  python collectors/imputer.py --indicator ECO_LOG --dry-run
  python collectors/imputer.py
  python collectors/imputer.py --category A
  python collectors/imputer.py --min-coverage 0.20

Ajout en base : layer_id = 2 (L2 = impute)
La normalisation L3 utilise layer_id = 2 si disponible,
sinon layer_id = 1.
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from typing import Optional

import numpy as np
import psycopg2
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("imputer")

# ── Seuils ────────────────────────────────────────────────
MIN_COVERAGE_IMPUTABLE = 0.20   # < 20% -> Categorie C -> pas d'imputation
MIN_VALUES_PER_COUNTRY = 2      # KNN : besoin d'au moins 2 valeurs connues
LAYER_RAW       = 1
LAYER_IMPUTED   = 2

# ── Classification des indicateurs ────────────────────────
#
# Categorie A -- publication periodique connue
# Categorie B -- nulls epars -- imputation par serie temporelle + KNN
# Categorie C -- couverture trop faible -- changer de source
#
# La categorisation automatique est faite par detect_category()
# mais on peut forcer manuellement ici.

FORCED_CATEGORY: dict[str, str] = {
    "ECO_LOG": "A",   # LPI -- tous les 2 ans (2010, 2012, 2014, 2016, 2018, 2022)
}

# ── Connexion DB ──────────────────────────────────────────
def get_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Chargement des donnees L1 ─────────────────────────────
def load_indicator(conn, indicator_code: str) -> dict:
    """
    Charge toutes les valeurs L1 d'un indicateur.
    Retourne un dict : {(iso3, year): value_or_None}
    et les listes de pays et annees.
    """
    with conn.cursor() as cur:
        cur.execute("""
            SELECT country_iso3, year, raw_value, quality_flag
            FROM ma.indicator_values
            WHERE indicator_code = %s AND layer_id = %s
            ORDER BY country_iso3, year
        """, (indicator_code, LAYER_RAW))
        rows = cur.fetchall()

    data = {}
    countries = set()
    years = set()
    for iso3, year, value, flag in rows:
        data[(iso3, year)] = value
        countries.add(iso3)
        years.add(year)

    return {
        "data":      data,
        "countries": sorted(countries),
        "years":     sorted(years),
        "total":     len(rows),
        "non_null":  sum(1 for v in data.values() if v is not None),
    }


# ── Detection automatique de categorie ───────────────────
def detect_category(info: dict, indicator_code: str) -> str:
    """
    Detecte automatiquement la categorie de nulls.
    A : nulls groupes par annee (publication periodique)
    B : nulls epars par pays
    C : couverture globale < MIN_COVERAGE_IMPUTABLE
    """
    if indicator_code in FORCED_CATEGORY:
        return FORCED_CATEGORY[indicator_code]

    coverage = info["non_null"] / max(info["total"], 1)
    if coverage < MIN_COVERAGE_IMPUTABLE:
        return "C"

    # Verifier si les nulls sont groupes par annee (Categorie A)
    # -- si certaines annees ont 0 valeurs et d'autres en ont beaucoup
    data = info["data"]
    years = info["years"]
    year_coverage = {}
    for y in years:
        vals = [data.get((c, y)) for c in info["countries"]]
        year_coverage[y] = sum(1 for v in vals if v is not None)

    zero_years   = sum(1 for v in year_coverage.values() if v == 0)
    nonzero_years = sum(1 for v in year_coverage.values() if v > 0)

    # Si plus de 30% des annees sont totalement vides -> Categorie A
    if zero_years > 0 and zero_years / max(len(years), 1) >= 0.30:
        return "A"

    return "B"


# ── CATEGORIE A -- Interpolation periodique ───────────────
def impute_periodic(info: dict) -> dict[tuple, float]:
    """
    Interpolation lineaire entre annees connues.
    Utilise pour ECO_LOG (LPI bi-annuel).

    Ex: 2010=3.2, 2012=3.5 -> 2011=3.35
    Ex: 2010=3.2, manque 2011-2021, 2022=4.1 -> interpolation lineaire

    Pour les annees avant la premiere valeur ou apres la derniere :
    on utilise forward/backward fill (pas d'extrapolation).
    """
    data      = info["data"]
    countries = info["countries"]
    years     = info["years"]
    imputed   = {}

    for iso3 in countries:
        # Recuperer les valeurs connues pour ce pays
        known = {y: data[(iso3, y)] for y in years
                 if data.get((iso3, y)) is not None}

        if len(known) < 2:
            # Pas assez de points pour interpoler -- forward/backward fill
            if len(known) == 1:
                val = list(known.values())[0]
                for y in years:
                    if data.get((iso3, y)) is None:
                        imputed[(iso3, y)] = round(float(val), 6)
            continue

        known_years = sorted(known.keys())
        known_vals  = [known[y] for y in known_years]

        for y in years:
            if data.get((iso3, y)) is not None:
                continue  # valeur deja presente

            if y < known_years[0]:
                # Avant la premiere valeur -- backward fill
                imputed[(iso3, y)] = round(float(known_vals[0]), 6)
            elif y > known_years[-1]:
                # Apres la derniere valeur -- forward fill
                imputed[(iso3, y)] = round(float(known_vals[-1]), 6)
            else:
                # Interpolation lineaire entre les deux valeurs encadrantes
                # Trouver y_before et y_after
                y_before = max(ky for ky in known_years if ky < y)
                y_after  = min(ky for ky in known_years if ky > y)
                v_before = known[y_before]
                v_after  = known[y_after]
                # Interpolation lineaire
                alpha = (y - y_before) / (y_after - y_before)
                interpolated = float(v_before) + alpha * (float(v_after) - float(v_before))
                imputed[(iso3, y)] = round(interpolated, 6)

    return imputed


# ── CATEGORIE B -- Imputation eparse (serie + KNN) ────────
def impute_sparse(info: dict) -> dict[tuple, float]:
    """
    Imputation des nulls epars.
    Etape 1 : interpolation lineaire intra-pays (si >= 2 valeurs)
    Etape 2 : forward/backward fill intra-pays (si 1 valeur)
    Etape 3 : KNN inter-pays (mediane des k voisins les plus proches)
              pour les pays sans aucune valeur
    """
    data      = info["data"]
    countries = info["countries"]
    years     = info["years"]
    imputed   = {}

    # ── Etape 1 & 2 : intra-pays ─────────────────────────
    for iso3 in countries:
        known = {y: data[(iso3, y)] for y in years
                 if data.get((iso3, y)) is not None}

        if len(known) == 0:
            continue  # Sera traite par KNN

        if len(known) == 1:
            # Forward/backward fill
            val = list(known.values())[0]
            for y in years:
                if data.get((iso3, y)) is None:
                    imputed[(iso3, y)] = round(float(val), 6)
            continue

        # Interpolation lineaire
        known_years = sorted(known.keys())
        known_vals  = [known[y] for y in known_years]

        for y in years:
            if data.get((iso3, y)) is not None:
                continue

            if y < known_years[0]:
                imputed[(iso3, y)] = round(float(known_vals[0]), 6)
            elif y > known_years[-1]:
                imputed[(iso3, y)] = round(float(known_vals[-1]), 6)
            else:
                y_before = max(ky for ky in known_years if ky < y)
                y_after  = min(ky for ky in known_years if ky > y)
                alpha    = (y - y_before) / (y_after - y_before)
                val      = float(known[y_before]) + alpha * (float(known[y_after]) - float(known[y_before]))
                imputed[(iso3, y)] = round(val, 6)

    # ── Etape 3 : KNN inter-pays ──────────────────────────
    # Pour les pays qui n'ont aucune valeur dans L1 + etapes 1-2
    countries_no_data = [
        iso3 for iso3 in countries
        if all(data.get((iso3, y)) is None for y in years)
        and all((iso3, y) not in imputed for y in years)
    ]

    if not countries_no_data:
        return imputed

    log.info("  KNN : %d pays sans aucune valeur -- calcul des voisins", len(countries_no_data))

    # Construire la matrice pays x annees avec toutes les valeurs disponibles
    # (L1 + imputation intra-pays)
    def get_val(iso3, y):
        v = data.get((iso3, y))
        if v is not None:
            return float(v)
        return imputed.get((iso3, y))

    for iso3_target in countries_no_data:
        for y in years:
            # Collecter les valeurs de tous les autres pays pour cette annee
            neighbor_vals = []
            for iso3_other in countries:
                if iso3_other == iso3_target:
                    continue
                v = get_val(iso3_other, y)
                if v is not None:
                    neighbor_vals.append(v)

            if len(neighbor_vals) >= 3:
                # Mediane des voisins disponibles (KNN simplifie)
                imputed[(iso3_target, y)] = round(float(np.median(neighbor_vals)), 6)

    return imputed


# ── CATEGORIE C -- Couverture insuffisante ────────────────
def flag_low_coverage(indicator_code: str, info: dict) -> None:
    """
    Signale les indicateurs avec couverture < MIN_COVERAGE_IMPUTABLE.
    Pas d'imputation -- recommande un changement de source.
    """
    coverage = info["non_null"] / max(info["total"], 1)
    log.warning(
        "  [C] %s -- couverture %.1f%% < %.0f%% -- imputation impossible "
        "-- changer de source recommande",
        indicator_code, coverage * 100, MIN_COVERAGE_IMPUTABLE * 100
    )


# ── Insertion en base (layer_id = 2) ──────────────────────
def insert_imputed(
    conn,
    indicator_code: str,
    imputed: dict[tuple, float],
    dry_run: bool = False,
) -> int:
    """
    Insere les valeurs imputees dans ma.indicator_values avec layer_id = 2.
    Copie les metadonnees de la ligne L1 correspondante.
    """
    if not imputed:
        return 0

    if dry_run:
        log.info("  [DRY-RUN] %s -> %d valeurs imputees (non inserees)",
                 indicator_code, len(imputed))
        return len(imputed)

    inserted = 0
    with conn.cursor() as cur:
        for (iso3, year), value in imputed.items():
            try:
                cur.execute("""
                    INSERT INTO ma.indicator_values
                        (indicator_code, country_iso3, year, layer_id,
                         raw_value, processed_value, method_version_id, quality_flag)
                    SELECT
                        indicator_code, country_iso3, %s, %s,
                        %s, NULL, method_version_id, 'INTERPOLATED'
                    FROM ma.indicator_values
                    WHERE indicator_code = %s
                      AND country_iso3   = %s
                      AND layer_id       = %s
                    LIMIT 1
                    ON CONFLICT DO NOTHING
                """, (year, LAYER_IMPUTED, value,
                      indicator_code, iso3, LAYER_RAW))
                inserted += cur.rowcount
            except Exception as e:
                log.warning("  Erreur insertion (%s, %s, %s) : %s",
                            indicator_code, iso3, year, e)
                conn.rollback()
                continue
        conn.commit()

    return inserted


# ── Orchestrateur principal ───────────────────────────────
def run_imputation(
    indicator_filter: Optional[str] = None,
    category_filter:  Optional[str] = None,
    min_coverage:     float = MIN_COVERAGE_IMPUTABLE,
    dry_run:          bool  = False,
) -> dict:
    """
    Lance l'imputation sur tous les indicateurs (ou un seul).
    Retourne un rapport de resultats.
    """
    conn = get_conn()
    report = {
        "A": {"indicators": [], "imputed_total": 0},
        "B": {"indicators": [], "imputed_total": 0},
        "C": {"indicators": [], "imputed_total": 0},
        "skipped": [],
    }

    try:
        # Recuperer la liste des indicateurs avec des nulls
        with conn.cursor() as cur:
            if indicator_filter:
                cur.execute("""
                    SELECT DISTINCT indicator_code
                    FROM ma.indicator_values
                    WHERE layer_id = %s AND indicator_code = %s
                """, (LAYER_RAW, indicator_filter))
            else:
                cur.execute("""
                    SELECT indicator_code,
                           COUNT(*) as total,
                           COUNT(raw_value) as non_null
                    FROM ma.indicator_values
                    WHERE layer_id = %s
                    GROUP BY indicator_code
                    HAVING COUNT(*) > COUNT(raw_value)
                    ORDER BY indicator_code
                """, (LAYER_RAW,))
            rows = cur.fetchall()

        indicators = [r[0] for r in rows]
        log.info("=== Imputation L2 -- %d indicateurs avec nulls ===", len(indicators))

        for code in indicators:
            log.info("[%s]", code)
            info = load_indicator(conn, code)
            coverage = info["non_null"] / max(info["total"], 1)

            # Detection categorie
            cat = detect_category(info, code)

            if category_filter and cat != category_filter:
                report["skipped"].append(code)
                continue

            log.info("  Categorie %s | Couverture %.1f%% | %d valeurs connues",
                     cat, coverage * 100, info["non_null"])

            if cat == "C" or coverage < min_coverage:
                flag_low_coverage(code, info)
                report["C"]["indicators"].append(code)
                continue

            # Imputation selon categorie
            if cat == "A":
                imputed = impute_periodic(info)
                report["A"]["indicators"].append(code)
                report["A"]["imputed_total"] += len(imputed)
            else:  # B
                imputed = impute_sparse(info)
                report["B"]["indicators"].append(code)
                report["B"]["imputed_total"] += len(imputed)

            n = insert_imputed(conn, code, imputed, dry_run)
            log.info("  -> %d valeurs imputees%s",
                     n, " (dry-run)" if dry_run else " inserees en L2")

    finally:
        conn.close()

    return report


# ── Rapport de resultats ──────────────────────────────────
def print_report(report: dict) -> None:
    print("\n" + "="*60)
    print("RAPPORT D'IMPUTATION L2")
    print("="*60)
    print(f"\n[A] Interpolation periodique : {len(report['A']['indicators'])} indicateurs")
    for code in report["A"]["indicators"]:
        print(f"    {code}")
    print(f"    -> {report['A']['imputed_total']} valeurs imputees")

    print(f"\n[B] Imputation eparse (serie + KNN) : {len(report['B']['indicators'])} indicateurs")
    for code in report["B"]["indicators"]:
        print(f"    {code}")
    print(f"    -> {report['B']['imputed_total']} valeurs imputees")

    print(f"\n[C] Couverture insuffisante -- changer source : {len(report['C']['indicators'])} indicateurs")
    for code in report["C"]["indicators"]:
        print(f"    {code}")

    if report["skipped"]:
        print(f"\n[~] Sautes (filtre categorie) : {len(report['skipped'])}")

    total_imputed = report["A"]["imputed_total"] + report["B"]["imputed_total"]
    print(f"\nTOTAL valeurs imputees : {total_imputed}")
    print("="*60)


# ── Point d'entree ────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Imputation L2 des valeurs manquantes",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Categories :
  A  Interpolation periodique (ECO_LOG LPI bi-annuel)
  B  Imputation eparse serie temporelle + KNN (HUM_LIT, MIL_PER...)
  C  Couverture insuffisante -- changer source (MON_EXT, NUM_RES...)

Exemples :
  python imputer.py --dry-run
  python imputer.py --indicator ECO_LOG --dry-run
  python imputer.py --category A --dry-run
  python imputer.py --min-coverage 0.25
  python imputer.py
        """,
    )
    parser.add_argument("--indicator",    type=str,   default=None)
    parser.add_argument("--category",     type=str,   default=None, choices=["A","B","C"])
    parser.add_argument("--min-coverage", type=float, default=MIN_COVERAGE_IMPUTABLE)
    parser.add_argument("--dry-run",      action="store_true")
    args = parser.parse_args()

    if args.dry_run:
        log.info("MODE DRY-RUN -- aucune ecriture en base")

    report = run_imputation(
        indicator_filter = args.indicator,
        category_filter  = args.category,
        min_coverage     = args.min_coverage,
        dry_run          = args.dry_run,
    )
    print_report(report)
    sys.exit(0)


if __name__ == "__main__":
    main()
