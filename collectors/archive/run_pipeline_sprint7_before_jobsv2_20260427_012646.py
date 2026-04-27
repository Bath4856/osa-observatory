"""
============================================================
OSA Observatory — collectors/run_pipeline_sprint7.py
Sprint 7 — Avril 2026
============================================================
Orchestrateur de collecte L1 — 10 piliers ISA
Lance les fetchers pilier par pilier avec suivi.

Modes :
  --probe     → sonde la couverture actuelle en base (L1)
  --dry-run   → simule la collecte sans écriture
  --collect   → collecte réelle (CSV + DB)
  --resume    → reprend depuis le dernier point d'arrêt
  --pillar    → traite un seul pilier
  --reset     → efface le checkpoint (repart de zéro)

Reprise sur arrêt :
  Un fichier checkpoint (logs/pipeline_checkpoint.json) enregistre
  l'état de chaque fetcher après chaque exécution.
  --resume repart du premier fetcher non complété.

Usage :
  python collectors/run_pipeline_sprint7.py --probe
  python collectors/run_pipeline_sprint7.py --dry-run
  python collectors/run_pipeline_sprint7.py --collect
  python collectors/run_pipeline_sprint7.py --resume
  python collectors/run_pipeline_sprint7.py --pillar PECO --collect
  python collectors/run_pipeline_sprint7.py --reset
============================================================
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("run_pipeline_sprint7")

# ── Répertoire collectors ─────────────────────────────────
COLLECTORS_DIR = Path(__file__).parent
PYTHON = sys.executable

# ── Définition des jobs par pilier ────────────────────────
# Chaque job = (fetcher, args_extra)
# Les args_extra sont ajoutés à la commande de base

PILLAR_JOBS = {
    "PECO": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PECO"]),
        ("fetcher_comtrade_api.py",       []),          # ECO_EXP/IMP
        ("fetcher_imf.py",                []),          # ECO_GDP/GRW via IMF API
        ("fetcher_imf_weo_csv.py",        []),          # ECO_GDP/GRW WEO CSV
        ("fetcher_imf_dots_csv.py",       []),          # ECO_IMP/EXP DOTS CSV
        ("fetcher_unctad.py",             []),          # ECO_FDI via UNCTAD API
        ("fetcher_unctad_csv.py",         []),          # ECO_FDI/IMP UNCTAD CSV
    ],
    "PENV": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PENV"]),
        ("fetcher_fao.py",               []),           # ENV_FOR via FAO API
        ("fetcher_fao_csv.py",           []),           # ENV_FOR/WATER FAO CSV
    ],
    "PGEO": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PGEO"]),
        ("fetcher_wgi_csv.py",           []),           # GEO_RSK/STAB WGI natif CSV
        ("fetcher_acled_csv.py",         []),           # GEO conflits ACLED CSV
        ("fetcher_unpk_csv.py",          []),           # GEO_PEA UNPK CSV
    ],
    "PHUM": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PHUM"]),
        ("fetcher_who.py",               []),           # HUM_SAN/WAT via WHO API
        ("fetcher_undp.py",              []),           # HUM_POV via UNDP API
        ("fetcher_undp_csv.py",          []),           # HUM_POV UNDP CSV
        ("fetcher_unesco.py",            []),           # HUM_LIT/EDU via UNESCO API
    ],
    "PMIL": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PMIL"]),
        ("fetcher_itu.py",               []),           # PMIL_GCI_CYBER
        ("fetcher_wgi_csv.py",           []),           # PMIL_STABILITY_WGI natif
        ("fetcher_sipri_csv.py",         []),           # PMIL_ARMS CSV
        ("fetcher_sipri_milex.py",       []),           # PMIL_DEF_BUDGET SIPRI
        ("fetcher_acled_csv.py",         []),           # PMIL conflits ACLED CSV
    ],
    "PMIN": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PMIN"]),
        ("fetcher_comtrade_api.py",       []),          # MIN_EXP Comtrade
        ("fetcher_unctad_csv.py",         []),          # MIN export UNCTAD CSV
        ("fetcher_usgs_csv.py",           []),          # MIN production USGS CSV
        ("fetcher_eiti_csv.py",           []),          # MIN_GOV/TAX EITI CSV
    ],
    "PMON": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PMON"]),
        ("fetcher_imf.py",               []),           # MON_EXT/PAY IMF API
        ("fetcher_imf_bop_csv.py",       []),           # MON_PAY BOP CSV
        ("fetcher_imf_weo_csv.py",       []),           # MON_EXT WEO CSV
    ],
    "PNUM": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PNUM"]),
        ("fetcher_itu.py",               []),           # PNUM_ITU_REG + PNUM_GCI
        ("fetcher_egdi.py",              []),           # PNUM_EGDI_*
        ("fetcher_unesco.py",            []),           # PNUM capital humain
    ],
    "PRES": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PRES"]),
        ("fetcher_fao.py",               []),           # PRES_WATER via FAO API
        ("fetcher_fao_csv.py",           []),           # PRES_WATER FAO CSV
    ],
    "PTRA": [
        ("fetcher_wb_ptra.py",  ["--skip-lsci"]),
        ("fetcher_unctad.py",   []),
        ("fetcher_lpi.py",      []),
    ],
}

PILLAR_ORDER = ["PMIN", "PMON", "PECO", "PGEO", "PMIL", "PHUM", "PENV", "PNUM", "PRES", "PTRA"]

# ── Checkpoint ────────────────────────────────────────────
CHECKPOINT_FILE = Path(__file__).parent.parent / "logs" / "pipeline_checkpoint.json"

def checkpoint_load() -> dict:
    """Charge le checkpoint existant ou retourne un dict vide."""
    if CHECKPOINT_FILE.exists():
        try:
            with open(CHECKPOINT_FILE, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def checkpoint_save(state: dict) -> None:
    """Sauvegarde le checkpoint sur disque."""
    CHECKPOINT_FILE.parent.mkdir(parents=True, exist_ok=True)
    state["updated_at"] = datetime.now().isoformat()
    with open(CHECKPOINT_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)

def checkpoint_mark(state: dict, pillar: str, fetcher: str, status: str) -> None:
    """Marque un fetcher comme terminé dans le checkpoint."""
    key = f"{pillar}::{fetcher}"
    state[key] = {
        "pillar":     pillar,
        "fetcher":    fetcher,
        "status":     status,
        "done_at":    datetime.now().isoformat(),
    }
    checkpoint_save(state)

def checkpoint_is_done(state: dict, pillar: str, fetcher: str) -> bool:
    """Retourne True si ce fetcher a déjà été complété avec succès."""
    key = f"{pillar}::{fetcher}"
    return state.get(key, {}).get("status") == "OK"

def checkpoint_reset() -> None:
    """Efface le checkpoint."""
    if CHECKPOINT_FILE.exists():
        CHECKPOINT_FILE.unlink()
        log.info("Checkpoint effacé — prochain run repart de zéro.")
    else:
        log.info("Aucun checkpoint à effacer.")

def checkpoint_print(state: dict) -> None:
    """Affiche l'état du checkpoint."""
    if not state:
        print("Aucun checkpoint — pipeline n'a pas encore tourné.")
        return
    updated = state.get("updated_at", "?")
    print(f"\n{'='*60}")
    print(f"CHECKPOINT — dernière mise à jour : {updated}")
    print(f"{'='*60}")
    for pillar in PILLAR_ORDER:
        jobs = PILLAR_JOBS.get(pillar, [])
        done = sum(1 for f, _ in jobs if checkpoint_is_done(state, pillar, f))
        total = len(jobs)
        status = "✓ COMPLET" if done == total else (f"~ {done}/{total}" if done > 0 else "✗ PAS COMMENCÉ")
        print(f"  {pillar:<6} {status}")
        for fetcher, _ in jobs:
            key = f"{pillar}::{fetcher}"
            info = state.get(key, {})
            icon = "✓" if info.get("status") == "OK" else ("✗" if info.get("status") == "KO" else "·")
            ts = info.get("done_at", "")[:16] if info else ""
            print(f"         {icon} {fetcher:<42} {ts}")
    print(f"{'='*60}\n")


# ── Connexion PostgreSQL ──────────────────────────────────
def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Rapport de couverture L1 ──────────────────────────────
def probe_coverage() -> dict:
    """Retourne la couverture L1 par pilier."""
    conn = get_pg_conn()
    results = {}
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    p.code,
                    p.name_fr,
                    COUNT(DISTINCT i.code)                          AS total_ind,
                    COUNT(DISTINCT iv.indicator_code)               AS ind_avec_l1,
                    COUNT(DISTINCT iv.country_iso3)                 AS pays_couverts,
                    COALESCE(MIN(iv.year), 0)                       AS yr_min,
                    COALESCE(MAX(iv.year), 0)                       AS yr_max,
                    COUNT(iv.id)                                    AS total_lignes
                FROM rf.pillars p
                LEFT JOIN rf.indicators i
                    ON i.pillar_code = p.code AND i.is_active = true
                LEFT JOIN ma.indicator_values iv
                    ON iv.indicator_code = i.code AND iv.layer_id = 1
                GROUP BY p.code, p.name_fr, p.display_order
                ORDER BY p.display_order
            """)
            for row in cur.fetchall():
                code, name, total, avec_l1, pays, yr_min, yr_max, lignes = row
                results[code] = {
                    "name":       name,
                    "total_ind":  total or 0,
                    "ind_l1":     avec_l1 or 0,
                    "pays":       pays or 0,
                    "yr_min":     yr_min,
                    "yr_max":     yr_max,
                    "lignes":     lignes or 0,
                    "pct":        round((avec_l1 or 0) * 100 / max(total or 1, 1), 1),
                }
    finally:
        conn.close()
    return results


def print_probe(results: dict) -> None:
    print("\n" + "=" * 80)
    print(f"OSA OBSERVATORY — COUVERTURE L1 — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print("=" * 80)
    print(f"{'Pilier':<6} {'Nom':<35} {'Ind':>5} {'L1':>5} {'Pays':>5} {'Années':>12} {'Lignes':>8} {'%':>6}")
    print("-" * 80)

    total_lignes = 0
    for code in PILLAR_ORDER:
        if code not in results:
            continue
        r = results[code]
        annees = f"{r['yr_min']}–{r['yr_max']}" if r['lignes'] > 0 else "—"
        status = "✓" if r['pct'] >= 50 else ("~" if r['pct'] > 0 else "✗")
        print(f"{code:<6} {r['name'][:35]:<35} {r['total_ind']:>5} {r['ind_l1']:>5} "
              f"{r['pays']:>5} {annees:>12} {r['lignes']:>8} {r['pct']:>5.1f}% {status}")
        total_lignes += r['lignes']

    print("-" * 80)
    print(f"{'TOTAL':<6} {'':<35} {'':>5} {'':>5} {'':>5} {'':>12} {total_lignes:>8}")
    print("=" * 80)

    # Piliers sans données
    vides = [c for c in PILLAR_ORDER if results.get(c, {}).get('lignes', 0) == 0]
    if vides:
        print(f"\n⚠  Piliers sans données L1 : {', '.join(vides)}")
        print("   → Lancer : python run_pipeline_sprint7.py --collect")
    else:
        print("\n✓  Tous les piliers ont des données L1")
    print()


# ── Lancement d'un fetcher ────────────────────────────────
def run_fetcher(
    fetcher: str,
    extra_args: list,
    mode: str,          # "dry-run" | "collect"
    output: str = "both",
) -> tuple[int, str]:
    """
    Lance un fetcher en subprocess.
    Retourne (returncode, stdout_summary).
    """
    script = COLLECTORS_DIR / fetcher
    if not script.exists():
        log.warning("  [SKIP] %s — fichier absent", fetcher)
        return 0, f"SKIP — {fetcher} absent"

    cmd = [PYTHON, str(script)] + extra_args + ["--output", output]
    if mode == "dry-run":
        cmd.append("--dry-run")

    log.info("  → %s", " ".join(cmd[2:]))  # sans le chemin python

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,  # 10 minutes max par fetcher
        )
        # Extraire les dernières lignes utiles du stdout
        lines = (result.stdout + result.stderr).strip().split("\n")
        summary = "\n".join(l for l in lines if any(
            kw in l for kw in ["insérés", "Insérés", "OK", "KO", "SKIP", "Total", "ERROR", "WARN"]
        ))
        return result.returncode, summary or lines[-1] if lines else ""
    except subprocess.TimeoutExpired:
        return -1, "TIMEOUT — fetcher trop lent (>10 min)"
    except Exception as e:
        return -1, f"Erreur subprocess : {e}"


# ── Traitement d'un pilier ────────────────────────────────
def process_pillar(
    pillar: str,
    mode: str,
    output: str = "both",
    checkpoint: dict = None,
    resume: bool = False,
) -> dict:
    """
    Lance tous les fetchers d'un pilier.
    Si resume=True, saute les fetchers déjà complétés.
    """
    jobs = PILLAR_JOBS.get(pillar, [])
    if not jobs:
        return {"pillar": pillar, "status": "NO_JOBS", "fetchers": []}

    if checkpoint is None:
        checkpoint = {}

    # Compter les fetchers à sauter
    skipped = sum(1 for f, _ in jobs if resume and checkpoint_is_done(checkpoint, pillar, f))
    todo = len(jobs) - skipped

    log.info("─" * 60)
    log.info("Pilier %s — %d fetcher(s) | mode: %s%s",
             pillar, len(jobs), mode.upper(),
             f" | {skipped} déjà complétés (reprise)" if skipped > 0 else "")

    if todo == 0:
        log.info("  ✓ Pilier déjà complet — ignoré")
        return {"pillar": pillar, "status": "OK", "fetchers": [], "skipped": skipped}

    results = []
    for fetcher, extra in jobs:
        # Reprise — sauter les fetchers déjà OK
        if resume and checkpoint_is_done(checkpoint, pillar, fetcher):
            log.info("  [SKIP] %s — déjà complété", fetcher)
            results.append({
                "fetcher":  fetcher,
                "rc":       0,
                "status":   "SKIP",
                "duration": 0,
                "summary":  "Déjà complété (reprise)",
            })
            continue

        t0 = time.monotonic()
        rc, summary = run_fetcher(fetcher, extra, mode, output)
        duration = round(time.monotonic() - t0, 1)
        status = "OK" if rc == 0 else "KO"

        # Sauvegarder dans le checkpoint (seulement en mode collect)
        if mode == "collect":
            checkpoint_mark(checkpoint, pillar, fetcher, status)

        results.append({
            "fetcher":  fetcher,
            "rc":       rc,
            "status":   status,
            "duration": duration,
            "summary":  summary,
        })
        log.info("    [%s] %s — %.1fs", status, fetcher, duration)
        if summary:
            for line in summary.split("\n")[:3]:
                if line.strip():
                    log.info("       %s", line.strip())

    overall = "OK" if all(r["rc"] == 0 for r in results) else "PARTIAL"
    return {"pillar": pillar, "status": overall, "fetchers": results}


# ── Rapport final ─────────────────────────────────────────
def print_final_report(
    job_results: list,
    mode: str,
    duration: float,
) -> None:
    print("\n" + "=" * 70)
    print(f"RAPPORT PIPELINE SPRINT 7 — mode {mode.upper()}")
    print(f"Durée totale : {duration:.1f}s")
    print("=" * 70)

    for r in job_results:
        status_icon = "✓" if r["status"] == "OK" else ("~" if r["status"] == "PARTIAL" else "✗")
        print(f"\n  {status_icon} {r['pillar']} — {r['status']}")
        for f in r.get("fetchers", []):
            icon = "✓" if f["rc"] == 0 else "✗"
            print(f"    {icon} {f['fetcher']:<40} {f['duration']:>5.1f}s  [{f['status']}]")

    ok = sum(1 for r in job_results if r["status"] == "OK")
    print(f"\n  {ok}/{len(job_results)} piliers OK")

    if mode == "collect":
        print("\nProchaines étapes :")
        print("  1. python collectors/imputer_v3.py --dry-run")
        print("  2. python collectors/imputer_v3.py")
        print("  3. CALL ma.run_pipeline_historical(2010::smallint, 2024::smallint, 1);")
        print("  4. python collectors/check_l3.py --full")
    print("=" * 70)


# ── Main ──────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA — Orchestrateur collecte L1 Sprint 7",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modes :
  --probe     Rapport de couverture L1 actuelle (lecture seule)
  --dry-run   Simulation collecte sans écriture
  --collect   Collecte réelle → CSV + DB
  --resume    Reprend depuis le dernier point d'arrêt
  --reset     Efface le checkpoint (repart de zéro)

Exemples :
  python run_pipeline_sprint7.py --probe
  python run_pipeline_sprint7.py --dry-run
  python run_pipeline_sprint7.py --collect
  python run_pipeline_sprint7.py --resume
  python run_pipeline_sprint7.py --pillar PECO --collect
  python run_pipeline_sprint7.py --reset
        """
    )
    parser.add_argument("--probe",    action="store_true", help="Rapport couverture L1")
    parser.add_argument("--dry-run",  action="store_true", help="Simulation sans écriture")
    parser.add_argument("--collect",  action="store_true", help="Collecte réelle")
    parser.add_argument("--resume",   action="store_true", help="Reprendre depuis checkpoint")
    parser.add_argument("--reset",    action="store_true", help="Effacer le checkpoint")
    parser.add_argument("--status",   action="store_true", help="Afficher l'état du checkpoint")
    parser.add_argument("--pillar",   type=str, default=None,
                        choices=list(PILLAR_JOBS.keys()),
                        help="Traiter un seul pilier")
    parser.add_argument("--output",   choices=["csv", "db", "both"], default="both")

    args = parser.parse_args()

    # ── Reset checkpoint ─────────────────────────────────
    if args.reset:
        checkpoint_reset()
        sys.exit(0)

    # ── Afficher checkpoint ──────────────────────────────
    if args.status:
        state = checkpoint_load()
        checkpoint_print(state)
        sys.exit(0)

    # ── Probe ────────────────────────────────────────────
    if args.probe or (not args.dry_run and not args.collect and not args.resume):
        log.info("Sondage couverture L1...")
        coverage = probe_coverage()
        print_probe(coverage)
        if not args.dry_run and not args.collect and not args.resume:
            sys.exit(0)

    # ── Mode ─────────────────────────────────────────────
    if args.resume:
        mode = "collect"
        resume = True
    elif args.dry_run:
        mode = "dry-run"
        resume = False
    elif args.collect:
        mode = "collect"
        resume = False
    else:
        sys.exit(0)

    # ── Charger checkpoint ───────────────────────────────
    checkpoint = checkpoint_load()
    if resume and checkpoint:
        log.info("Reprise depuis checkpoint — %d étapes déjà complétées",
                 sum(1 for v in checkpoint.values()
                     if isinstance(v, dict) and v.get("status") == "OK"))
        checkpoint_print(checkpoint)
    elif resume and not checkpoint:
        log.info("Aucun checkpoint trouvé — démarrage complet")
        resume = False

    # ── Sélection piliers ────────────────────────────────
    pillars_to_run = [args.pillar] if args.pillar else PILLAR_ORDER

    # En mode resume, filtrer les piliers déjà entièrement complétés
    if resume:
        pillars_to_run = [
            p for p in pillars_to_run
            if not all(checkpoint_is_done(checkpoint, p, f)
                       for f, _ in PILLAR_JOBS.get(p, []))
        ]
        if not pillars_to_run:
            log.info("✓ Tous les piliers sont déjà complétés !")
            sys.exit(0)
        log.info("Piliers restants : %s", ", ".join(pillars_to_run))

    log.info("=" * 60)
    log.info("OSA Pipeline Sprint 7 — mode %s%s",
             mode.upper(), " (REPRISE)" if resume else "")
    log.info("Piliers : %s", ", ".join(pillars_to_run))
    log.info("Output  : %s", args.output)
    log.info("Début   : %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    log.info("=" * 60)

    t_global = time.monotonic()
    job_results = []

    for pillar in pillars_to_run:
        result = process_pillar(
            pillar, mode, args.output,
            checkpoint=checkpoint,
            resume=resume,
        )
        job_results.append(result)
        time.sleep(1)

    total_duration = round(time.monotonic() - t_global, 1)
    print_final_report(job_results, mode, total_duration)

    # Probe après collecte
    if mode == "collect":
        log.info("\nCouverture L1 après collecte :")
        coverage = probe_coverage()
        print_probe(coverage)

    all_ok = all(r["status"] in ("OK", "PARTIAL") for r in job_results)
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()