#!/usr/bin/env python3
"""
patch_nginx_prod_api.py -- Insere le bloc `location /api/` manquant dans
la configuration nginx de open.osa-observatory.africa (prod).

Diagnostic du 12 juillet 2026 : aucun bloc /api/ n'existe dans
/etc/nginx/sites-available/portal -- toute requete POST vers /api/...
tombe dans le bloc generique `location /` (try_files), qui refuse les
methodes non-GET sur du contenu statique (405 Not Allowed). Confirme
par test direct sur le port 8000 (contourne nginx) : osa-api repond
normalement (422 sur payload vide, pas 405).

Idempotent -- si le bloc /api/ existe deja, ne fait rien et le signale.

Usage :
  sudo python3 patch_nginx_prod_api.py
"""
import sys

PATH = "/etc/nginx/sites-available/portal"

API_BLOCK = """    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
"""

MARKER = "    location / { try_files $uri $uri/ /index.html; }"


def main():
    with open(PATH) as f:
        content = f.read()

    if "location /api/" in content:
        print("Rien à faire -- un bloc 'location /api/' existe déjà dans le fichier.")
        sys.exit(0)

    if MARKER not in content:
        print(f"Erreur -- ligne de repère introuvable dans {PATH} :", file=sys.stderr)
        print(f"  {MARKER!r}", file=sys.stderr)
        print("Le fichier a peut-être changé depuis le diagnostic -- insertion manuelle requise.", file=sys.stderr)
        sys.exit(1)

    new_content = content.replace(MARKER, API_BLOCK + MARKER)

    with open(PATH, "w") as f:
        f.write(new_content)

    print(f"OK -- bloc 'location /api/' inséré dans {PATH}, avant le bloc générique.")
    print("Prochaine étape : sudo nginx -t   (valider la syntaxe avant tout reload)")


if __name__ == "__main__":
    main()
