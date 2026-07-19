#!/usr/bin/env python3
"""
identity_synchronizer.py -- Service de synchronisation d'identite (ADR-001)
Lit les evenements PENDING cibles PROD dans mg.identity_events sur
osa_preprod, applique chacun via l'endpoint interne de l'API prod
(jamais de SQL brut ecrit directement sur la cible -- reutilise les
memes requetes parametrees que le reste de l'API), puis met a jour le
statut de l'evenement sur preprod (PROPAGATED ou FAILED).

Mode scrutation periodique (pas de service temps reel) -- coherent avec
le volume actuel du projet. A lancer manuellement ou via cron.

Usage :
  ~/flyer-venv/bin/python3 identity_synchronizer.py

Variables d'environnement :
  IDENTITY_SYNC_SECRET  (obligatoire -- doit correspondre a la valeur
                          configuree dans api/.env de la cible prod)
  PROD_API_BASE         (defaut: https://open.osa-observatory.africa/api)
"""
import json
import os
import subprocess
import sys
from datetime import date
from pathlib import Path

import requests
import qrcode
from weasyprint import HTML

PROD_API_BASE = os.getenv("PROD_API_BASE", "https://open.osa-observatory.africa/api")
SYNC_SECRET = os.getenv("IDENTITY_SYNC_SECRET")

SCRIPT_DIR = Path(__file__).resolve().parent
ACTIVATION_TEMPLATE_PATH = SCRIPT_DIR / "flyer_activation_template.html"
LOGO_PATH = SCRIPT_DIR / "logo.png"
FLYER_DIR = Path(os.getenv("FLYER_DIR", str(Path.home() / "flyers")))


def sql_literal(value) -> str:
    """Echappement SQL manuel -- la substitution psql -v / :'var' n'est pas
    fonctionnelle de maniere fiable dans cet environnement Docker
    (limitation deja rencontree et documentee sur ce projet). On construit
    donc la requete cote Python, avec doublement des apostrophes -- seule
    methode d'echappement necessaire pour du texte entre guillemets simples
    en SQL standard."""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def psql(database: str, sql: str):
    """Execute une requete deja entierement formee (toute donnee dynamique
    doit avoir ete passee par sql_literal() au prealable)."""
    cmd = ["docker", "exec", "-i", "osa-db", "psql", "-U", "postgres", "-d", database,
           "-t", "-A", "-q", "-c", sql]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"psql error ({database}): {result.stderr.strip()}")
    return result.stdout.strip()


def generate_activation_flyer(first_name: str, last_name: str, email: str, activation_url: str) -> Path:
    """Genere localement le flyer d'activation prod -- meme patron que le
    flyer d'invitation preprod : disponible pour transmission manuelle,
    jamais joint automatiquement a l'e-mail (parite avec l'existant)."""
    FLYER_DIR.mkdir(parents=True, exist_ok=True)

    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=10, border=2)
    qr.add_data(activation_url)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="#0F4A1A", back_color="white")
    safe_email = email.replace("@", "_at_").replace(".", "_")
    qr_path = FLYER_DIR / f"_qr_tmp_activation_{safe_email}.png"
    qr_img.save(qr_path)

    html_content = ACTIVATION_TEMPLATE_PATH.read_text(encoding="utf-8")
    html_content = html_content.replace('src="logo.png"', f'src="{LOGO_PATH}"')
    html_content = html_content.replace('src="qr_sample.png"', f'src="{qr_path}"')
    html_content = html_content.replace("{{PRENOM}}", first_name)
    html_content = html_content.replace("{{NOM}}", last_name)
    html_content = html_content.replace("{{ACTIVATION_URL}}", activation_url)
    html_content = html_content.replace("{{DATE}}", date.today().strftime("%B %Y"))

    pdf_path = FLYER_DIR / f"flyer_activation_{safe_email}.pdf"
    HTML(string=html_content).write_pdf(str(pdf_path))
    qr_path.unlink()
    return pdf_path


def fetch_pending_events():
    raw = psql("osa_preprod", """
        SELECT COALESCE(json_agg(e), '[]'::json)
        FROM (
            SELECT event_uuid, event_type, affiliate_uuid::text AS affiliate_uuid, payload
            FROM mg.identity_events
            WHERE target_environment = 'PROD' AND status = 'PENDING'
            ORDER BY created_at
        ) e;
    """)
    return json.loads(raw) if raw else []


def mark_event(database: str, event_uuid: str, status: str, error_detail: str = ""):
    error_sql = sql_literal(error_detail) if error_detail else "NULL"
    psql(database, f"""
        UPDATE mg.identity_events
        SET status = {sql_literal(status)}, propagated_at = NOW(),
            propagated_by = 'IDENTITY_SYNCHRONIZER', error_detail = {error_sql}
        WHERE event_uuid = {sql_literal(event_uuid)};
    """)


def apply_event(event: dict) -> tuple[bool, str, dict]:
    try:
        res = requests.post(
            f"{PROD_API_BASE}/v1/affiliation/sync/apply-event",
            headers={"X-Sync-Secret": SYNC_SECRET, "Content-Type": "application/json"},
            json={
                "event_type": event["event_type"],
                "affiliate_uuid": event["affiliate_uuid"],
                "payload": event["payload"],
            },
            timeout=15,
        )
        if res.ok:
            return True, "", res.json()
        return False, f"HTTP {res.status_code} -- {res.text[:500]}", {}
    except requests.RequestException as e:
        return False, str(e)[:500], {}


def main():
    if not SYNC_SECRET:
        print("Erreur : IDENTITY_SYNC_SECRET non défini.", file=sys.stderr)
        sys.exit(1)

    events = fetch_pending_events()
    if not events:
        print("Aucun événement en attente.")
        return

    print(f"→ {len(events)} événement(s) en attente de propagation vers PROD.")
    ok_count = fail_count = 0

    for event in events:
        success, error, response = apply_event(event)
        if success:
            print(f"  ✓ {event['event_type']} ({event['affiliate_uuid'][:8]}...) propagé.")
            ok_count += 1

            # La comptabilite (marquage PROPAGATED) ne doit jamais faire
            # perdre de vue qu'un succes reel a deja eu lieu -- ni bloquer
            # le traitement des evenements suivants.
            try:
                mark_event("osa_preprod", event["event_uuid"], "PROPAGATED")
            except Exception as e:
                print(f"    ⚠ Propagation reussie mais non enregistree dans le journal ({e}). "
                      f"Cet evenement sera retente au prochain passage -- verifier une eventuelle "
                      f"duplication cote prod avant relance.", file=sys.stderr)

            if event["event_type"] == "AFFILIATE_CONFIRMED" and response.get("action") == "created":
                if response.get("email_sent") is False:
                    print(f"    ⚠ E-mail d'activation non envoyé : {response.get('email_error')}", file=sys.stderr)

                if response.get("activation_url"):
                    p = event["payload"]
                    try:
                        flyer_path = generate_activation_flyer(
                            p["first_name"], p["last_name"], p["email"], response["activation_url"]
                        )
                        print(f"    → Flyer d'activation généré : {flyer_path}")
                    except Exception as e:
                        print(f"    ⚠ Flyer non généré ({e}) -- le compte reste valide.", file=sys.stderr)
        else:
            try:
                mark_event("osa_preprod", event["event_uuid"], "FAILED", error)
            except Exception as mark_err:
                print(f"    ⚠ Echec non plus enregistre dans le journal ({mark_err}).", file=sys.stderr)
            print(f"  ✗ {event['event_type']} ({event['affiliate_uuid'][:8]}...) échec : {error}", file=sys.stderr)
            fail_count += 1

    print(f"\nTerminé -- {ok_count} propagé(s), {fail_count} échec(s).")


if __name__ == "__main__":
    main()
