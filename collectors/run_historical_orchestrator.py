"""
OSA Historical Pipeline Orchestrator
-------------------------------------
Corrections appliquées :
  #1  Mot de passe sorti du code → variables d'environnement (DB_*)
  #2  Niveau configurable via argument CLI (argparse)
  #3  check_quality() utilise l'année de fin du niveau choisi, pas 2022 en dur
  #4  NO_GO bloque le pipeline sur tous les niveaux, pas seulement probe
  #5  Connexion partagée dans run_sql() via un context manager réutilisable
  #6  sys.executable remplace "python" pour garantir le bon interpréteur
  #7  try/except autour de check_quality() + logging structuré
"""

import argparse
import logging
import os
import subprocess
import sys
import time
from contextlib import contextmanager

import psycopg2

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("osa_pipeline")

# ---------------------------------------------------------------------------
# #1 — Connexion via variables d'environnement (plus de mot de passe en clair)
# ---------------------------------------------------------------------------
DB_CONFIG = {
    "dbname":   os.environ.get("DB_NAME",     "osa"),
    "user":     os.environ.get("DB_USER",     "postgres"),
    "password": os.environ.get("DB_PASSWORD", ""),        # obligatoire en prod
    "host":     os.environ.get("DB_HOST",     "localhost"),
    "port":     os.environ.get("DB_PORT",     "5432"),
}

FETCHERS_ORDER = [
    "WB", "EITI", "WHO", "ITU",
    "IMF_WEO", "IMF_DOTS", "IMF_BOP",
    "FAO", "UNDP", "SIPRI", "USGS", "ACLED",
]

# Plages d'années par niveau
LEVEL_YEARS = {
    "probe":      (2022, 2022),
    "warmup":     (2022, 2024),
    "historical": (2010, 2024),
}

# ---------------------------------------------------------------------------
# #5 — Connexion partagée via context manager
# ---------------------------------------------------------------------------
@contextmanager
def get_connection():
    conn = psycopg2.connect(**DB_CONFIG)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def run_sql(query, params=None):
    """Exécute une requête et retourne toutes les lignes."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()


# ---------------------------------------------------------------------------
# #3 — check_quality reçoit l'année en paramètre (plus de 2022 en dur)
# ---------------------------------------------------------------------------
def check_quality(year: int) -> str:
    """
    Retourne 'GO', 'PARTIAL' ou 'NO_GO' selon le nombre d'indicateurs couverts
    pour l'année donnée.
    """
    rows = run_sql(
        "SELECT status, COUNT(*) "
        "FROM collect.compute_quality_score(%s) "
        "GROUP BY status;",
        (year,),
    )
    stats = {r[0]: r[1] for r in rows}
    go = stats.get("GO", 0)
    if go >= 80:
        return "GO"
    elif go >= 40:
        return "PARTIAL"
    else:
        return "NO_GO"


# ---------------------------------------------------------------------------
# #6 — sys.executable remplace "python"
# ---------------------------------------------------------------------------
def run_fetcher(fetcher: str, year_from: int, year_to: int) -> bool:
    """Lance le script fetcher_X.py et retourne True si succès."""
    cmd = [
        sys.executable,                          # #6 : bon interpréteur garanti
        f"fetcher_{fetcher.lower()}.py",
        "--from", str(year_from),
        "--to",   str(year_to),
    ]
    log.info("Démarrage  %s  (%d → %d)", fetcher, year_from, year_to)
    start = time.monotonic()
    result = subprocess.run(cmd)
    duration = round(time.monotonic() - start, 1)

    if result.returncode != 0:
        log.error("ECHEC  %s  (%ss)", fetcher, duration)
        return False

    log.info("OK  %s  (%ss)", fetcher, duration)
    return True


# ---------------------------------------------------------------------------
# #2 #3 #4 #7 — run_pipeline corrigé
# ---------------------------------------------------------------------------
def run_pipeline(level: str = "probe") -> None:
    """
    Orchestre les fetchers dans l'ordre.
    - level : 'probe' | 'warmup' | 'historical'
    - La qualité est vérifiée sur l'année de FIN du niveau (#3).
    - Un NO_GO bloque le pipeline quel que soit le niveau (#4).
    - Les exceptions de check_quality sont capturées et loguées (#7).
    """
    if level not in LEVEL_YEARS:
        raise ValueError(f"Niveau inconnu : {level!r}. Valeurs : {list(LEVEL_YEARS)}")

    year_from, year_to = LEVEL_YEARS[level]

    log.info("=== OSA HISTORICAL PIPELINE [%s] ===", level.upper())
    log.info("Plage : %d → %d  |  Qualité vérifiée sur : %d", year_from, year_to, year_to)

    for fetcher in FETCHERS_ORDER:

        # --- Run fetcher ---
        ok = run_fetcher(fetcher, year_from, year_to)
        if not ok:
            log.warning("Skip suivant — erreur sur %s", fetcher)
            continue

        # --- Vérification qualité (#3 : année de fin, #7 : try/except) ---
        try:
            quality = check_quality(year_to)          # #3 — année dynamique
        except Exception as exc:                       # #7 — pas de crash silencieux
            log.error("Impossible de vérifier la qualité : %s", exc)
            quality = "NO_GO"

        log.info("Qualité après %s : %s", fetcher, quality)

        # #4 — Blocage sur NO_GO pour TOUS les niveaux
        if quality == "NO_GO":
            log.critical("STOP — qualité NO_GO détectée après %s", fetcher)
            break

    log.info("Pipeline terminé.")


# ---------------------------------------------------------------------------
# #2 — Argument CLI pour choisir le niveau
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OSA Historical Pipeline")
    parser.add_argument(
        "--level",
        choices=list(LEVEL_YEARS),
        default="probe",
        help="Niveau d'exécution (défaut : probe)",
    )
    args = parser.parse_args()
    run_pipeline(args.level)
