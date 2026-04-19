"""
============================================================
OSA / ISA OBSERVATORY
collectors/check_l3.py — Audit et validation L2 → L3
============================================================

Vérifie la qualité de la normalisation L2 → L3 pour tous
les indicateurs actifs ou un sous-ensemble filtré.

Contrôles effectués :
  [C1]  Valeurs L3 dans [0.0, 1.0]                         CRITIQUE
  [C2]  Aucun NaN introduit par la normalisation            CRITIQUE
  [C3]  Direction appliquée correctement (+/-)              CRITIQUE
  [C4]  Couverture L3 >= couverture L2 (pas de perte)       CRITIQUE
  [C5]  Pas d'indicateur min=max (division par zéro)        AVERTISSEMENT
  [C6]  Cohérence L1→L2→L3 (pas d'orphelins)               AVERTISSEMENT
  [C7]  PTRA_PORT_* = 0.0 pour pays enclavés sans accord    AVERTISSEMENT
  [C8]  Pas de pilier avec < 3 indicateurs normalisés        AVERTISSEMENT
  [C9]  Scores de confiance L3 cohérents (non nuls)         INFO
  [C10] Distribution L3 par indicateur (stats descriptives) INFO

Codes de sortie :
  0 — Aucune anomalie critique
  1 — Au moins une anomalie critique détectée
  2 — Erreur technique (connexion DB, etc.)

Usage :
  python collectors/check_l3.py --dry-run
  python collectors/check_l3.py --pillar PTRA
  python collectors/check_l3.py --pillar PRES
  python collectors/check_l3.py --indicator PTRA_LOG_LPI
  python collectors/check_l3.py --year 2022
  python collectors/check_l3.py --year 2022 --pillar PECO
  python collectors/check_l3.py --full
  python collectors/check_l3.py --full --output rapport_l3.txt
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from datetime import datetime
from typing import Optional

import numpy as np
import pandas as pd
import psycopg2
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("check_l3")

# ── Niveaux de sévérité ───────────────────────────────────────
SEV_CRITIQUE     = "CRITIQUE"
SEV_AVERTISSEMENT = "AVERTISSEMENT"
SEV_INFO         = "INFO"

# ── Seuils ────────────────────────────────────────────────────
L3_MIN           = 0.0
L3_MAX           = 1.0
L3_TOLERANCE     = 1e-6   # tolérance arrondi flottant
MIN_INDICATORS_PER_PILLAR = 3
COVERAGE_LOSS_MAX = 0.02  # tolérance 2% de perte L2→L3


# ── Connexion ────────────────────────────────────────────────
def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Chargement des données ────────────────────────────────────
def load_layers(conn, pillar_filter=None, indicator_filter=None, year_filter=None):
    """
    Charge L1, L2, L3 depuis ma.indicator_values.
    Retourne trois DataFrames et les métadonnées indicateurs.
    """
    params_base  = []
    where_extra  = []

    if pillar_filter:
        where_extra.append("i.pillar_code = %s")
        params_base.append(pillar_filter)
    if indicator_filter:
        where_extra.append("iv.indicator_code = %s")
        params_base.append(indicator_filter)
    if year_filter:
        where_extra.append("iv.year = %s")
        params_base.append(year_filter)

    extra_sql = ("AND " + " AND ".join(where_extra)) if where_extra else ""

    query = f"""
        SELECT iv.indicator_code, iv.country_iso3, iv.year,
               iv.raw_value, iv.processed_value,
               iv.layer_id, iv.confidence_score, iv.value_status,
               i.pillar_code, i.direction, i.is_active
        FROM ma.indicator_values iv
        JOIN rf.indicators i ON i.code = iv.indicator_code
        WHERE i.is_active = TRUE
          AND iv.layer_id IN (1, 2, 3)
          {extra_sql}
        ORDER BY iv.indicator_code, iv.country_iso3, iv.year, iv.layer_id
    """

    df_all = pd.read_sql(query, conn, params=params_base if params_base else None)

    df_meta = pd.read_sql(f"""
        SELECT i.code, i.pillar_code, i.direction,
               i.is_port_indicator,
               p.imputation_regime
        FROM rf.indicators i
        JOIN rf.pillars p ON p.code = i.pillar_code
        WHERE i.is_active = TRUE
          {"AND i.pillar_code = %s" if pillar_filter else ""}
          {"AND i.code = %s" if indicator_filter else ""}
        ORDER BY i.pillar_code, i.code
    """, conn, params=[x for x in [pillar_filter, indicator_filter] if x])

    df_landlocked = pd.read_sql("""
        SELECT iso3 FROM rf.countries WHERE is_landlocked = TRUE
    """, conn)
    landlocked_set = set(df_landlocked["iso3"].tolist())

    df_l1 = df_all[df_all["layer_id"] == 1].copy()
    df_l2 = df_all[df_all["layer_id"] == 2].copy()
    df_l3 = df_all[df_all["layer_id"] == 3].copy()

    log.info("Données chargées — L1: %d | L2: %d | L3: %d lignes | %d indicateurs",
             len(df_l1), len(df_l2), len(df_l3),
             df_all["indicator_code"].nunique())

    return df_l1, df_l2, df_l3, df_meta, landlocked_set


# ── Structure d'une anomalie ─────────────────────────────────
class Anomalie:
    def __init__(self, code: str, severite: str, indicateur: str,
                 message: str, detail: str = ""):
        self.code       = code
        self.severite   = severite
        self.indicateur = indicateur
        self.message    = message
        self.detail     = detail

    def __str__(self):
        s = f"[{self.severite}][{self.code}] {self.indicateur} — {self.message}"
        if self.detail:
            s += f"\n    {self.detail}"
        return s


# ── Contrôles ────────────────────────────────────────────────

def check_c1_bornes(df_l3: pd.DataFrame) -> list[Anomalie]:
    """[C1] Valeurs L3 dans [0.0, 1.0] — CRITIQUE."""
    anomalies = []
    if df_l3.empty:
        return anomalies

    col = "processed_value"
    if col not in df_l3.columns:
        return anomalies

    for ind_code, grp in df_l3.groupby("indicator_code"):
        vals = grp[col].dropna()
        if vals.empty:
            continue

        hors_borne = vals[
            (vals < L3_MIN - L3_TOLERANCE) |
            (vals > L3_MAX + L3_TOLERANCE)
        ]
        if not hors_borne.empty:
            mins = float(hors_borne.min())
            maxs = float(hors_borne.max())
            pays = grp.loc[hors_borne.index, "country_iso3"].tolist()[:5]
            anomalies.append(Anomalie(
                "C1", SEV_CRITIQUE, ind_code,
                f"{len(hors_borne)} valeurs hors [0,1]",
                f"min={mins:.6f}, max={maxs:.6f}, ex. pays={pays}"
            ))
    return anomalies


def check_c2_nan_introduits(df_l2: pd.DataFrame, df_l3: pd.DataFrame) -> list[Anomalie]:
    """[C2] Valeurs présentes en L2 mais NaN en L3 — CRITIQUE."""
    anomalies = []
    if df_l2.empty or df_l3.empty:
        return anomalies

    key = ["indicator_code", "country_iso3", "year"]

    l2_keys = set(zip(df_l2["indicator_code"], df_l2["country_iso3"], df_l2["year"]))
    l3_with_val = df_l3[df_l3["processed_value"].notna()]
    l3_keys = set(zip(l3_with_val["indicator_code"],
                      l3_with_val["country_iso3"],
                      l3_with_val["year"]))

    for ind_code in df_l2["indicator_code"].unique():
        l2_ind = {k for k in l2_keys if k[0] == ind_code}
        l3_ind = {k for k in l3_keys if k[0] == ind_code}
        perdus = l2_ind - l3_ind
        if perdus:
            anomalies.append(Anomalie(
                "C2", SEV_CRITIQUE, ind_code,
                f"{len(perdus)} valeurs L2 absentes ou NaN en L3",
                f"ex. (pays, année) = {list(perdus)[:3]}"
            ))
    return anomalies


def check_c3_direction(df_l1: pd.DataFrame, df_l3: pd.DataFrame,
                       df_meta: pd.DataFrame) -> list[Anomalie]:
    """
    [C3] Direction appliquée correctement.
    Pour direction='+' : corrélation L1/L3 doit être positive.
    Pour direction='-' : corrélation L1/L3 doit être négative.
    """
    anomalies = []
    if df_l1.empty or df_l3.empty or df_meta.empty:
        return anomalies

    meta_dir = dict(zip(df_meta["code"], df_meta["direction"]))

    for ind_code in df_l3["indicator_code"].unique():
        direction = meta_dir.get(ind_code)
        if not direction:
            continue

        l1_ind = df_l1[df_l1["indicator_code"] == ind_code][
            ["country_iso3", "year", "raw_value"]
        ].dropna()
        l3_ind = df_l3[df_l3["indicator_code"] == ind_code][
            ["country_iso3", "year", "processed_value"]
        ].dropna()

        if len(l1_ind) < 10 or len(l3_ind) < 10:
            continue

        merged = l1_ind.merge(l3_ind, on=["country_iso3", "year"])
        if len(merged) < 10:
            continue

        corr = merged["raw_value"].corr(merged["processed_value"])
        if pd.isna(corr):
            continue

        if direction == "+" and corr < -0.10:
            anomalies.append(Anomalie(
                "C3", SEV_CRITIQUE, ind_code,
                f"Direction='+' mais corrélation L1/L3 négative (r={corr:.3f})",
                "La normalisation inverse peut-être la direction incorrectement."
            ))
        elif direction == "-" and corr > 0.10:
            anomalies.append(Anomalie(
                "C3", SEV_CRITIQUE, ind_code,
                f"Direction='-' mais corrélation L1/L3 positive (r={corr:.3f})",
                "L'inversion de direction semble absente ou incorrecte."
            ))
    return anomalies


def check_c4_couverture(df_l2: pd.DataFrame, df_l3: pd.DataFrame) -> list[Anomalie]:
    """[C4] Couverture L3 >= couverture L2 (tolérance 2%) — CRITIQUE."""
    anomalies = []
    if df_l2.empty or df_l3.empty:
        return anomalies

    for ind_code in df_l2["indicator_code"].unique():
        n_l2 = df_l2[df_l2["indicator_code"] == ind_code]["processed_value"].notna().sum()
        n_l3 = df_l3[df_l3["indicator_code"] == ind_code]["processed_value"].notna().sum()

        if n_l2 == 0:
            continue

        perte = (n_l2 - n_l3) / n_l2
        if perte > COVERAGE_LOSS_MAX:
            anomalies.append(Anomalie(
                "C4", SEV_CRITIQUE, ind_code,
                f"Perte de couverture L2→L3 : {perte*100:.1f}% ({n_l2} → {n_l3})",
                f"Seuil tolérance : {COVERAGE_LOSS_MAX*100:.0f}%"
            ))
    return anomalies


def check_c5_min_max(df_l1: pd.DataFrame) -> list[Anomalie]:
    """[C5] Indicateurs avec min=max (division par zéro à la normalisation) — AVERTISSEMENT."""
    anomalies = []
    if df_l1.empty:
        return anomalies

    for ind_code, grp in df_l1.groupby("indicator_code"):
        vals = grp["raw_value"].dropna()
        if vals.empty:
            continue
        if vals.min() == vals.max():
            anomalies.append(Anomalie(
                "C5", SEV_AVERTISSEMENT, ind_code,
                f"min=max={vals.min():.4f} — division par zéro à la normalisation",
                f"Tous les pays ont la même valeur L1. "
                f"La normalisation produit NaN ou une valeur constante."
            ))
    return anomalies


def check_c6_orphelins(df_l1: pd.DataFrame, df_l2: pd.DataFrame,
                       df_l3: pd.DataFrame) -> list[Anomalie]:
    """[C6] Valeurs L3 sans correspondance L1/L2 (orphelins) — AVERTISSEMENT."""
    anomalies = []
    if df_l3.empty:
        return anomalies

    l1_keys = set(zip(df_l1["indicator_code"], df_l1["country_iso3"], df_l1["year"]))
    l2_keys = set(zip(df_l2["indicator_code"], df_l2["country_iso3"], df_l2["year"]))
    l1_l2   = l1_keys | l2_keys

    for ind_code in df_l3["indicator_code"].unique():
        l3_ind = df_l3[df_l3["indicator_code"] == ind_code]
        l3_keys = set(zip(l3_ind["indicator_code"],
                          l3_ind["country_iso3"],
                          l3_ind["year"]))
        orphelins = l3_keys - l1_l2
        if orphelins:
            anomalies.append(Anomalie(
                "C6", SEV_AVERTISSEMENT, ind_code,
                f"{len(orphelins)} valeurs L3 sans correspondance en L1 ou L2",
                f"ex. = {list(orphelins)[:3]}"
            ))
    return anomalies


def check_c7_port_landlocked(df_l3: pd.DataFrame, df_meta: pd.DataFrame,
                              landlocked_set: set) -> list[Anomalie]:
    """
    [C7] PTRA_PORT_* = 0.0 attendu pour pays enclavés sans accord.
    Détecte les valeurs non nulles suspectes pour ces pays.
    """
    anomalies = []
    if df_l3.empty or df_meta.empty or not landlocked_set:
        return anomalies

    port_indicators = set(
        df_meta.loc[df_meta["is_port_indicator"] == True, "code"]  # noqa: E712
    )
    if not port_indicators:
        return anomalies

    for ind_code in port_indicators:
        mask = (
            (df_l3["indicator_code"] == ind_code) &
            (df_l3["country_iso3"].isin(landlocked_set))
        )
        grp = df_l3[mask]
        if grp.empty:
            continue

        # Valeurs > 0 pour pays enclavés — peuvent être légitimes (accords)
        # mais on signale pour vérification manuelle
        suspects = grp[grp["processed_value"] > 0.01]
        if not suspects.empty:
            pays = suspects["country_iso3"].unique().tolist()
            anomalies.append(Anomalie(
                "C7", SEV_AVERTISSEMENT, ind_code,
                f"{len(suspects)} valeurs L3 > 0 pour pays enclavés",
                f"Pays : {pays[:5]} — Vérifier que des accords portuaires justifient ces valeurs "
                f"dans rf.port_agreements."
            ))
    return anomalies


def check_c8_pilier_couverture(df_l3: pd.DataFrame,
                                df_meta: pd.DataFrame) -> list[Anomalie]:
    """[C8] Pas de pilier avec < 3 indicateurs normalisés en L3 — AVERTISSEMENT."""
    anomalies = []
    if df_l3.empty or df_meta.empty:
        return anomalies

    pillar_map = dict(zip(df_meta["code"], df_meta["pillar_code"]))
    df_l3["pillar_code"] = df_l3["indicator_code"].map(pillar_map)

    for pillar, grp in df_l3.groupby("pillar_code"):
        n_ind = grp["indicator_code"].nunique()
        if n_ind < MIN_INDICATORS_PER_PILLAR:
            anomalies.append(Anomalie(
                "C8", SEV_AVERTISSEMENT, f"Pilier {pillar}",
                f"Seulement {n_ind} indicateur(s) normalisé(s) en L3",
                f"Seuil minimum OSA : {MIN_INDICATORS_PER_PILLAR}. "
                f"Le pilier sera exclu du calcul ISA si < 3."
            ))
    return anomalies


def check_c9_confidence(df_l3: pd.DataFrame) -> list[Anomalie]:
    """[C9] Scores de confiance L3 cohérents — INFO."""
    anomalies = []
    if df_l3.empty:
        return anomalies
    if "confidence_score" not in df_l3.columns:
        return anomalies

    for ind_code, grp in df_l3.groupby("indicator_code"):
        conf = grp["confidence_score"].dropna()
        if conf.empty:
            anomalies.append(Anomalie(
                "C9", SEV_INFO, ind_code,
                "Aucun score de confiance en L3",
                "confidence_score est NULL pour tous les enregistrements."
            ))
            continue
        zero_conf = (conf == 0).sum()
        if zero_conf > 0:
            anomalies.append(Anomalie(
                "C9", SEV_INFO, ind_code,
                f"{zero_conf} scores de confiance = 0.0 en L3",
                "Un score de confiance nul est suspect — vérifier la normalisation."
            ))
    return anomalies


def stats_c10(df_l1: pd.DataFrame, df_l3: pd.DataFrame,
              df_meta: pd.DataFrame) -> pd.DataFrame:
    """[C10] Stats descriptives L3 par indicateur — INFO."""
    if df_l3.empty:
        return pd.DataFrame()

    rows = []
    meta_dir    = dict(zip(df_meta["code"], df_meta["direction"]))
    meta_pillar = dict(zip(df_meta["code"], df_meta["pillar_code"]))
    meta_regime = dict(zip(df_meta["code"], df_meta["imputation_regime"]))

    for ind_code, grp in df_l3.groupby("indicator_code"):
        vals = grp["processed_value"].dropna()
        if vals.empty:
            continue

        l1_grp   = df_l1[df_l1["indicator_code"] == ind_code]["raw_value"].dropna()
        n_l1     = len(l1_grp)
        n_l3     = len(vals)
        imputed  = n_l3 - n_l1
        imp_rate = imputed / n_l3 if n_l3 > 0 else 0

        rows.append({
            "pilier":     meta_pillar.get(ind_code, "?"),
            "regime":     meta_regime.get(ind_code, "?"),
            "indicateur": ind_code,
            "direction":  meta_dir.get(ind_code, "?"),
            "n_l3":       n_l3,
            "n_imputed":  max(imputed, 0),
            "imp_rate%":  round(imp_rate * 100, 1),
            "min":        round(float(vals.min()), 4),
            "p25":        round(float(vals.quantile(0.25)), 4),
            "median":     round(float(vals.median()), 4),
            "mean":       round(float(vals.mean()), 4),
            "p75":        round(float(vals.quantile(0.75)), 4),
            "max":        round(float(vals.max()), 4),
            "std":        round(float(vals.std()), 4),
        })

    return pd.DataFrame(rows).sort_values(["pilier", "indicateur"])


# ── Orchestrateur ─────────────────────────────────────────────
def run_audit(
    pillar_filter:    Optional[str] = None,
    indicator_filter: Optional[str] = None,
    year_filter:      Optional[int] = None,
    full:             bool = False,
    output_file:      Optional[str] = None,
) -> int:
    """
    Lance tous les contrôles et retourne le code de sortie.
    0 = OK, 1 = anomalies critiques, 2 = erreur technique.
    """
    lines = []

    def pr(s=""):
        lines.append(s)
        print(s)

    try:
        conn = get_pg_conn()
    except Exception as e:
        log.error("Connexion DB impossible : %s", e)
        return 2

    try:
        df_l1, df_l2, df_l3, df_meta, landlocked_set = load_layers(
            conn, pillar_filter, indicator_filter, year_filter
        )
    except Exception as e:
        log.error("Chargement données impossible : %s", e)
        conn.close()
        return 2
    finally:
        conn.close()

    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    pr("=" * 70)
    pr(f"OSA OBSERVATORY — Rapport d'audit L2 → L3")
    pr(f"Généré le : {ts}")
    if pillar_filter:
        pr(f"Filtre pilier     : {pillar_filter}")
    if indicator_filter:
        pr(f"Filtre indicateur : {indicator_filter}")
    if year_filter:
        pr(f"Filtre année      : {year_filter}")
    pr(f"L1: {len(df_l1)} lignes | L2: {len(df_l2)} | L3: {len(df_l3)}")
    pr(f"Indicateurs actifs : {df_l3['indicator_code'].nunique()}")
    pr("=" * 70)

    # ── Lancer tous les contrôles ────────────────────────────
    all_anomalies: list[Anomalie] = []

    pr("\n── Contrôles en cours...")
    all_anomalies += check_c1_bornes(df_l3)
    pr(f"  [C1] Bornes [0,1]          : {'OK' if not [a for a in all_anomalies if a.code=='C1'] else 'ANOMALIES'}")

    a_c2 = check_c2_nan_introduits(df_l2, df_l3)
    all_anomalies += a_c2
    pr(f"  [C2] NaN introduits        : {'OK' if not a_c2 else 'ANOMALIES'}")

    a_c3 = check_c3_direction(df_l1, df_l3, df_meta)
    all_anomalies += a_c3
    pr(f"  [C3] Direction +/-         : {'OK' if not a_c3 else 'ANOMALIES'}")

    a_c4 = check_c4_couverture(df_l2, df_l3)
    all_anomalies += a_c4
    pr(f"  [C4] Couverture L2→L3      : {'OK' if not a_c4 else 'ANOMALIES'}")

    a_c5 = check_c5_min_max(df_l1)
    all_anomalies += a_c5
    pr(f"  [C5] Indicateurs min=max   : {'OK' if not a_c5 else f'{len(a_c5)} avertissements'}")

    a_c6 = check_c6_orphelins(df_l1, df_l2, df_l3)
    all_anomalies += a_c6
    pr(f"  [C6] Orphelins L3          : {'OK' if not a_c6 else f'{len(a_c6)} avertissements'}")

    a_c7 = check_c7_port_landlocked(df_l3, df_meta, landlocked_set)
    all_anomalies += a_c7
    pr(f"  [C7] PORT enclavés         : {'OK' if not a_c7 else f'{len(a_c7)} à vérifier'}")

    a_c8 = check_c8_pilier_couverture(df_l3, df_meta)
    all_anomalies += a_c8
    pr(f"  [C8] Piliers < 3 indicateurs: {'OK' if not a_c8 else f'{len(a_c8)} avertissements'}")

    a_c9 = check_c9_confidence(df_l3)
    all_anomalies += a_c9
    pr(f"  [C9] Scores de confiance   : {'OK' if not a_c9 else f'{len(a_c9)} infos'}")

    # ── Résumé des anomalies ─────────────────────────────────
    critiques     = [a for a in all_anomalies if a.severite == SEV_CRITIQUE]
    avertissements = [a for a in all_anomalies if a.severite == SEV_AVERTISSEMENT]
    infos         = [a for a in all_anomalies if a.severite == SEV_INFO]

    pr("")
    pr("=" * 70)
    pr(f"RÉSUMÉ : {len(critiques)} CRITIQUE(S) | "
       f"{len(avertissements)} AVERTISSEMENT(S) | {len(infos)} INFO(S)")
    pr("=" * 70)

    if critiques:
        pr("\n── ANOMALIES CRITIQUES ─────────────────────────────────")
        for a in critiques:
            pr(str(a))

    if avertissements:
        pr("\n── AVERTISSEMENTS ──────────────────────────────────────")
        for a in avertissements:
            pr(str(a))

    if infos:
        pr("\n── INFORMATIONS ────────────────────────────────────────")
        for a in infos:
            pr(str(a))

    # ── Stats descriptives C10 ───────────────────────────────
    if full:
        pr("\n── [C10] STATS DESCRIPTIVES L3 PAR INDICATEUR ─────────")
        df_stats = stats_c10(df_l1, df_l3, df_meta)
        if not df_stats.empty:
            pr(df_stats.to_string(index=False))
        else:
            pr("  Aucune donnée L3 disponible.")

    # ── Conclusion ───────────────────────────────────────────
    pr("")
    pr("=" * 70)
    if critiques:
        pr("CONCLUSION : ÉCHEC — anomalies critiques détectées.")
        pr("  → Vérifier la normalisation L3 avant de recalculer les piliers.")
        exit_code = 1
    else:
        pr("CONCLUSION : OK — aucune anomalie critique.")
        if avertissements:
            pr("  → Vérifier les avertissements ci-dessus.")
        exit_code = 0
    pr("=" * 70)

    # ── Export fichier ───────────────────────────────────────
    if output_file:
        try:
            with open(output_file, "w", encoding="utf-8") as f:
                f.write("\n".join(lines))
            log.info("Rapport exporté : %s", output_file)
        except Exception as e:
            log.warning("Export fichier impossible : %s", e)

    return exit_code


# ── CLI ───────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA — Audit et validation L2 → L3",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Contrôles effectués :
  [C1] Valeurs L3 dans [0.0, 1.0]              CRITIQUE
  [C2] NaN introduits par la normalisation      CRITIQUE
  [C3] Direction +/- appliquée correctement     CRITIQUE
  [C4] Couverture L3 >= couverture L2           CRITIQUE
  [C5] Indicateurs min=max (div. par zéro)      AVERTISSEMENT
  [C6] Orphelins L3 sans correspondance L1/L2   AVERTISSEMENT
  [C7] PTRA_PORT_* = 0 pour pays enclavés       AVERTISSEMENT
  [C8] Piliers avec < 3 indicateurs normalisés  AVERTISSEMENT
  [C9] Scores de confiance L3 cohérents         INFO
  [C10] Stats descriptives L3 (--full)          INFO

Codes de sortie :
  0 — OK (aucune anomalie critique)
  1 — ÉCHEC (anomalies critiques détectées)
  2 — Erreur technique

Exemples :
  python collectors/check_l3.py
  python collectors/check_l3.py --pillar PTRA
  python collectors/check_l3.py --pillar PRES
  python collectors/check_l3.py --year 2022
  python collectors/check_l3.py --full
  python collectors/check_l3.py --full --output rapport_l3_$(date +%Y%m%d).txt
  python collectors/check_l3.py --pillar PTRA --full --output rapport_ptra_l3.txt
        """,
    )
    parser.add_argument("--pillar",    type=str, default=None,
                        help="Filtrer sur un pilier (ex: PTRA, PRES, PECO)")
    parser.add_argument("--indicator", type=str, default=None,
                        help="Filtrer sur un indicateur (ex: PTRA_LOG_LPI)")
    parser.add_argument("--year",      type=int, default=None,
                        help="Filtrer sur une année (ex: 2022)")
    parser.add_argument("--full",      action="store_true",
                        help="Inclure les stats descriptives C10")
    parser.add_argument("--output",    type=str, default=None,
                        help="Exporter le rapport dans un fichier texte")

    args = parser.parse_args()
    code = run_audit(
        pillar_filter=args.pillar,
        indicator_filter=args.indicator,
        year_filter=args.year,
        full=args.full,
        output_file=args.output,
    )
    sys.exit(code)


if __name__ == "__main__":
    main()
