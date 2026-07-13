#!/usr/bin/env python3
"""
onboard_founder.py -- Orchestration complete d'un affilie fondateur
Cree le compte (via /preaffiliate), genere le flyer PDF personnalise,
sauvegarde le tout localement. Plus besoin de copier-coller un JSON
a qui que ce soit -- une seule commande fait tout.

Usage :
  ~/flyer-venv/bin/python3 onboard_founder.py \
      --first-name "Amina" --last-name "Traore" \
      --email "amina.traore@example.com" \
      --target-type WORKING_GROUP --target-value PGEO

  ~/flyer-venv/bin/python3 onboard_founder.py \
      --first-name "Jean" --last-name "Dupont" \
      --email "jean.dupont@example.com" \
      --target-type COMMITTEE --target-value COMITE_TECH

Variables d'environnement :
  ADMIN_PASSWORD   (obligatoire)
  ADMIN_EMAIL      (defaut: theophile.bakang@gmail.com)
  API_BASE         (defaut: http://127.0.0.1:8001 -- preprod)
  BASE_URL         (defaut: https://preprod.osa-observatory.africa)
  TOKEN_DAYS       (defaut: 30)
  SEND_EMAIL       (defaut: true)
  FLYER_DIR        (defaut: ~/flyers)
"""
import argparse
import os
import sys
from datetime import date
from pathlib import Path

import requests
import qrcode
from weasyprint import HTML

SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE_PATH = SCRIPT_DIR / "flyer_template.html"
LOGO_PATH = SCRIPT_DIR / "logo.png"

TARGET_LABELS_FR = {
    "COMITE_TECH": "Comité technique",
    "COMITE_SCI": "Comité scientifique",
    "COMITE_ETHIQUE": "Comité d'éthique",
}
PILLAR_LABELS_FR = {
    "PGEO": "Géopolitique", "PECO": "Économique", "PMIL": "Militaire",
    "PMIN": "Minière", "PMON": "Monétaire", "PHUM": "Humaine",
    "PENV": "Environnementale", "PNUM": "Numérique", "PRES": "Énergétique",
    "PTRA": "Transport",
}


def build_destination_label(target_type, target_value):
    if target_type == "COMMITTEE":
        return TARGET_LABELS_FR.get(target_value, target_value)
    pillar_fr = PILLAR_LABELS_FR.get(target_value, target_value)
    return f"Groupe de travail — Pilier {target_value} ({pillar_fr})"


def main():
    parser = argparse.ArgumentParser(description="Onboarding complet d'un affilié fondateur")
    parser.add_argument("--first-name", required=True)
    parser.add_argument("--last-name", required=True)
    parser.add_argument("--email", required=True)
    parser.add_argument("--target-type", required=True, choices=["COMMITTEE", "WORKING_GROUP"])
    parser.add_argument("--target-value", required=True, help="ex. COMITE_TECH ou PGEO")
    args = parser.parse_args()

    admin_password = os.getenv("ADMIN_PASSWORD")
    if not admin_password:
        print("Erreur : variable ADMIN_PASSWORD non définie.", file=sys.stderr)
        sys.exit(1)

    admin_email = os.getenv("ADMIN_EMAIL", "theophile.bakang@gmail.com")
    api_base = os.getenv("API_BASE", "http://127.0.0.1:8001")
    base_url = os.getenv("BASE_URL", "https://preprod.osa-observatory.africa")
    token_days = int(os.getenv("TOKEN_DAYS", "30"))
    send_email = os.getenv("SEND_EMAIL", "true").lower() == "true"
    flyer_dir = Path(os.getenv("FLYER_DIR", str(Path.home() / "flyers")))
    flyer_dir.mkdir(parents=True, exist_ok=True)

    if not TEMPLATE_PATH.exists():
        print(f"Erreur : gabarit introuvable ({TEMPLATE_PATH}). "
              f"Placez flyer_template.html et logo.png a cote de ce script.", file=sys.stderr)
        sys.exit(1)

    # 1) Connexion admin
    print("→ Connexion admin...")
    r = requests.post(f"{api_base}/api/v2/affiliates/auth/login",
                       json={"email": admin_email, "password": admin_password})
    r.raise_for_status()
    token = r.json()["token"]

    # 2) Creation de l'affilie
    print(f"→ Création de l'affilié {args.first_name} {args.last_name} ({args.email})...")
    target_json = (
        {"type": "COMMITTEE", "committee_code": args.target_value}
        if args.target_type == "COMMITTEE"
        else {"type": "WORKING_GROUP", "pillar_code": args.target_value}
    )
    r = requests.post(
        f"{api_base}/api/v2/affiliates/admin/preaffiliate",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "first_name": args.first_name,
            "last_name": args.last_name,
            "email": args.email,
            "target": target_json,
            "token_expiry_days": token_days,
            "base_url": base_url,
            "send_email": send_email,
        },
    )
    if not r.ok:
        print(f"Erreur API ({r.status_code}) : {r.text}", file=sys.stderr)
        sys.exit(1)
    data = r.json()
    print(f"  affiliate_id={data['affiliate_id']}  email_sent={data['email_sent']}"
          + (f"  email_error={data['email_error']}" if data.get("email_error") else ""))

    # 3) Generation du QR code
    print("→ Génération du QR code...")
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=10, border=2)
    qr.add_data(data["confirm_url"])
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="#0F4A1A", back_color="white")
    qr_path = flyer_dir / f"_qr_tmp_{data['affiliate_id']}.png"
    qr_img.save(qr_path)

    # 4) Generation du flyer PDF
    print("→ Génération du flyer PDF...")
    html_content = TEMPLATE_PATH.read_text(encoding="utf-8")
    html_content = html_content.replace('src="logo.png"', f'src="{LOGO_PATH}"')
    html_content = html_content.replace('src="qr_sample.png"', f'src="{qr_path}"')
    html_content = html_content.replace("{{PRENOM}}", args.first_name)
    html_content = html_content.replace("{{NOM}}", args.last_name)
    html_content = html_content.replace("{{DESTINATION}}", build_destination_label(args.target_type, args.target_value))
    html_content = html_content.replace("{{CONFIRM_URL}}", data["confirm_url"])
    html_content = html_content.replace("{{DATE}}", date.today().strftime("%B %Y"))

    safe_email = args.email.replace("@", "_at_").replace(".", "_")
    pdf_path = flyer_dir / f"flyer_{safe_email}.pdf"
    HTML(string=html_content).write_pdf(str(pdf_path))
    qr_path.unlink()  # nettoyage du QR temporaire, integre au PDF

    print("")
    print(f"✓ Terminé.")
    print(f"  Flyer : {pdf_path}")
    print(f"  E-mail automatique envoyé : {data['email_sent']}")
    print(f"  L'affilié choisira lui-même son mot de passe en cliquant sur le lien de confirmation.")


if __name__ == "__main__":
    main()
