"""
launch_pipeline.py
═══════════════════════════════════════════════════════════════════════════
Lanceur de pipeline OSA en arrière-plan (Windows + cross-platform)

Fonctionnalités :
  - Lance run_pipeline_sprint7.py en arrière-plan
  - Log horodaté dans logs/
  - Statut du job en temps réel
  - Modes : collect | probe | dry-run | pillar | resume

Usage :
  python launch_pipeline.py                        # collecte complète
  python launch_pipeline.py --mode probe           # sonde couverture
  python launch_pipeline.py --mode dry-run         # simulation
  python launch_pipeline.py --pillar PMIN          # un seul pilier
  python launch_pipeline.py --pillar PGEO --mode collect
  python launch_pipeline.py --resume               # reprendre
  python launch_pipeline.py --status               # état du dernier job
  python launch_pipeline.py --follow               # suivre les logs en direct
═══════════════════════════════════════════════════════════════════════════
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

PROJECT       = Path(__file__).resolve().parent
COLLECTORS    = PROJECT / "collectors"
LOGS_DIR      = PROJECT / "logs"
PIPELINE      = COLLECTORS / "run_pipeline_sprint7.py"
PYTHON        = sys.executable
STATUS_FILE   = LOGS_DIR / "launch_status.json"

LOGS_DIR.mkdir(exist_ok=True)


# ── Construction de la commande ───────────────────────────────────────────────

def build_cmd(mode: str, pillar: str | None, resume: bool) -> list[str]:
    cmd = [PYTHON, str(PIPELINE)]

    if mode == "probe":
        cmd.append("--probe")
    elif mode == "dry-run":
        cmd += ["--dry-run"]
    elif mode == "collect":
        cmd.append("--collect")

    if pillar:
        cmd += ["--pillar", pillar.upper()]

    if resume:
        cmd.append("--resume")

    return cmd


# ── Lancement en arrière-plan ─────────────────────────────────────────────────

def launch(cmd: list[str], log_path: Path) -> subprocess.Popen:
    """Lance le process en arrière-plan avec redirection des logs."""
    log_file = open(log_path, "w", encoding="utf-8", buffering=1)

    proc = subprocess.Popen(
        cmd,
        stdout=log_file,
        stderr=subprocess.STDOUT,
        cwd=str(PROJECT),
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
    )
    return proc


# ── Sauvegarde du statut ──────────────────────────────────────────────────────

def save_status(pid: int, cmd: list, log_path: Path, started_at: str) -> None:
    status = {
        "pid":        pid,
        "cmd":        " ".join(cmd[1:]),   # sans le chemin python
        "log":        str(log_path),
        "started_at": started_at,
        "status":     "RUNNING",
    }
    STATUS_FILE.write_text(json.dumps(status, indent=2, ensure_ascii=False),
                           encoding="utf-8")


def load_status() -> dict | None:
    if not STATUS_FILE.exists():
        return None
    try:
        return json.loads(STATUS_FILE.read_text(encoding="utf-8"))
    except Exception:
        return None


def update_status(status: str) -> None:
    s = load_status()
    if s:
        s["status"]   = status
        s["ended_at"] = datetime.now().isoformat()
        STATUS_FILE.write_text(json.dumps(s, indent=2, ensure_ascii=False),
                               encoding="utf-8")


# ── Affichage du statut ───────────────────────────────────────────────────────

def print_status() -> None:
    s = load_status()
    if not s:
        print("Aucun job enregistré.")
        return

    print("\n" + "=" * 55)
    print("  OSA Pipeline — Dernier job")
    print("=" * 55)
    print(f"  PID        : {s['pid']}")
    print(f"  Commande   : {s['cmd']}")
    print(f"  Démarré    : {s['started_at']}")
    print(f"  Statut     : {s['status']}")
    if "ended_at" in s:
        print(f"  Terminé    : {s['ended_at']}")
    print(f"  Log        : {s['log']}")

    # Vérifier si le process tourne encore
    pid = s.get("pid")
    if pid and s["status"] == "RUNNING":
        alive = _is_alive(pid)
        print(f"  Process    : {'EN COURS' if alive else 'TERMINÉ (non détecté)'}")
        if not alive:
            update_status("DONE")

    # Dernières lignes du log
    log_path = Path(s["log"])
    if log_path.exists():
        lines = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()
        last  = [l for l in lines[-20:] if l.strip()]
        if last:
            print("\n  Dernières lignes :")
            for l in last:
                print(f"    {l}")
    print("=" * 55 + "\n")


def _is_alive(pid: int) -> bool:
    try:
        if os.name == "nt":
            result = subprocess.run(
                ["tasklist", "/FI", f"PID eq {pid}", "/NH"],
                capture_output=True, text=True
            )
            return str(pid) in result.stdout
        else:
            os.kill(pid, 0)
            return True
    except Exception:
        return False


# ── Suivi en direct des logs ──────────────────────────────────────────────────

def follow_logs(log_path: Path) -> None:
    """Affiche les logs en temps réel (Ctrl+C pour arrêter)."""
    print(f"Suivi de : {log_path}")
    print("(Ctrl+C pour arrêter le suivi — le pipeline continue en arrière-plan)\n")

    if not log_path.exists():
        print("Fichier log non trouvé.")
        return

    try:
        with open(log_path, encoding="utf-8", errors="ignore") as f:
            # Afficher le contenu existant
            for line in f:
                print(line, end="")
            # Suivre les nouvelles lignes
            while True:
                line = f.readline()
                if line:
                    print(line, end="", flush=True)
                else:
                    time.sleep(0.3)
    except KeyboardInterrupt:
        print("\n\nSuivi arrêté — le pipeline continue en arrière-plan.")
        print(f"Relancez avec : python launch_pipeline.py --follow")


# ── Point d'entrée ────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA — Lanceur de pipeline en arrière-plan"
    )
    parser.add_argument(
        "--mode",
        choices=["collect", "probe", "dry-run"],
        default="collect",
        help="Mode d'exécution (défaut: collect)",
    )
    parser.add_argument(
        "--pillar",
        metavar="PILIER",
        help="Traiter un seul pilier (ex: PMIN, PGEO, PMIL...)",
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Reprendre depuis le dernier point d'arrêt",
    )
    parser.add_argument(
        "--status", action="store_true",
        help="Afficher le statut du dernier job",
    )
    parser.add_argument(
        "--follow", action="store_true",
        help="Suivre les logs du dernier job en direct",
    )
    args = parser.parse_args()

    # ── Statut ────────────────────────────────────────────────────────────────
    if args.status:
        print_status()
        return

    # ── Suivi logs ────────────────────────────────────────────────────────────
    if args.follow:
        s = load_status()
        if not s:
            print("Aucun job enregistré.")
            return
        follow_logs(Path(s["log"]))
        return

    # ── Vérifications ─────────────────────────────────────────────────────────
    if not PIPELINE.exists():
        print(f"ERREUR : {PIPELINE} introuvable.")
        return

    # Vérifier qu'un job ne tourne pas déjà
    s = load_status()
    if s and s.get("status") == "RUNNING" and _is_alive(s.get("pid", 0)):
        print(f"Un job est déjà en cours (PID {s['pid']}).")
        print(f"  Log : {s['log']}")
        print(f"  Suivi : python launch_pipeline.py --follow")
        resp = input("\nLancer quand même ? [o/N] : ").strip().lower()
        if resp not in ("o", "oui", "y", "yes"):
            return

    # ── Construction commande ─────────────────────────────────────────────────
    cmd        = build_cmd(args.mode, args.pillar, args.resume)
    started_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ts         = datetime.now().strftime("%Y%m%d_%H%M%S")
    pillar_tag = f"_{args.pillar.upper()}" if args.pillar else ""
    log_path   = LOGS_DIR / f"pipeline_{args.mode}{pillar_tag}_{ts}.log"

    # ── Lancement ─────────────────────────────────────────────────────────────
    print("=" * 55)
    print("  OSA Pipeline — Lancement")
    print("=" * 55)
    print(f"  Mode     : {args.mode}")
    if args.pillar:
        print(f"  Pilier   : {args.pillar.upper()}")
    print(f"  Log      : {log_path}")
    print(f"  Commande : {' '.join(cmd[1:])}")
    print("=" * 55)

    proc = launch(cmd, log_path)
    save_status(proc.pid, cmd, log_path, started_at)

    print(f"\n  Lancé en arrière-plan (PID {proc.pid})")
    print(f"\n  Commandes utiles :")
    print(f"    python launch_pipeline.py --status   # état du job")
    print(f"    python launch_pipeline.py --follow   # logs en direct")
    print(f"    Get-Content {log_path} -Tail 30 -Wait")
    print()

    # Attendre 3 secondes pour détecter un échec immédiat
    time.sleep(3)
    if proc.poll() is not None and proc.returncode != 0:
        update_status("FAILED")
        print(f"  ERREUR — le process s'est arrêté immédiatement (code {proc.returncode})")
        print(f"  Consultez : {log_path}")
    else:
        print(f"  Pipeline en cours — suivez avec --follow")


if __name__ == "__main__":
    main()
