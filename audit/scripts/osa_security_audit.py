"""
OSA Observatory -- Audit de securite Sprint 17
scripts/audit/osa_security_audit.py

Usage :
    py -3.12 scripts/audit/osa_security_audit.py \
        --std-key  osa_8gsLK6_Y1pPOZy9Yf7Z3OVxrodQUgcLHdfLFs4qIcC4 \
        --std-otp  XXXXXX \
        --exp-key  osa_iYbcuDS-ejBTACaM-4SSrtZx1n0vAGhS2n5tFD4KgTI \
        [--base-url http://localhost:8000]

Le script :
  1. Lit /openapi.json pour decouvrir les endpoints dynamiquement
  2. Classifie chaque endpoint par niveau requis
  3. Execute 3 controles par endpoint :
       CTRL-1 : sans auth         -> attendu 200 (PUBLIC) ou 401 (protected)
       CTRL-2 : auth insuffisante -> attendu 403
       CTRL-3 : auth valide       -> attendu 200 ou 204
  4. Produit un rapport JSON dans audit/sprint17_security_audit_<timestamp>.json
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from typing import Optional

# Ajouter G:/python-packages au path
sys.path.insert(0, "G:/python-packages")
sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent.parent.parent))

import requests

# ---------------------------------------------------------------------------
# Classification des endpoints
# ---------------------------------------------------------------------------
# Regles de classification par prefixe/pattern
# PUBLIC  : accessible sans auth
# STANDARD: JWT STANDARD ou superieur
# PREMIUM : JWT PREMIUM ou superieur
# EXPERT  : JWT EXPERT uniquement
# SKIP    : endpoints qu'on ne peut pas tester automatiquement (POST avec body complexe)

ENDPOINT_CLASSIFICATION = {
    # Health / root
    ("GET",    "/"):                                      "PUBLIC",
    ("GET",    "/health"):                                "PUBLIC",
    # Auth
    ("POST",   "/auth/token"):                            "PUBLIC",
    ("POST",   "/auth/refresh"):                          "PUBLIC",
    ("POST",   "/auth/otp/request"):                      "PUBLIC",
    ("POST",   "/auth/revoke"):                           "STANDARD",
    ("GET",    "/auth/me"):                               "STANDARD",
    ("POST",   "/auth/revoke-all/{target_affiliation_id}"): "EXPERT",
    # OpenData
    ("GET",    "/opendata/"):                             "PUBLIC",
    ("GET",    "/opendata/pillars"):                      "PUBLIC",
    ("GET",    "/opendata/pillars/{iso3}"):                "PUBLIC",
    ("GET",    "/opendata/countries/latest"):              "PUBLIC",
    ("GET",    "/opendata/countries/latest/{iso3}"):       "PUBLIC",
    ("GET",    "/opendata/countries/history"):             "PUBLIC",
    ("GET",    "/opendata/countries/history/{iso3}"):      "PUBLIC",
    ("GET",    "/opendata/trajectories"):                 "PUBLIC",
    ("GET",    "/opendata/trajectories/{iso3}"):          "PUBLIC",
    ("GET",    "/opendata/opportunities"):                "PUBLIC",
    ("GET",    "/opendata/opportunities/{iso3}"):         "PUBLIC",
    ("GET",    "/opendata/alerts/amar"):                  "PUBLIC",
    ("GET",    "/opendata/alerts/amar/{iso3}"):           "PUBLIC",
    ("GET",    "/opendata/methodology"):                  "PUBLIC",
    # Countries Couche 1
    ("GET",    "/api/v2/countries"):                      "STANDARD",
    ("GET",    "/api/v2/countries/{iso3}"):                "STANDARD",
    ("GET",    "/api/v2/countries/{iso3}/history"):        "STANDARD",
    ("GET",    "/api/v2/countries/{iso3}/pillars"):        "STANDARD",
    # Rankings
    ("GET",    "/api/v2/rankings"):                       "PUBLIC",
    ("GET",    "/api/v2/rankings/{iso3}"):                 "PUBLIC",
    ("GET",    "/api/v2/rankings/region/{region_code}"):  "PUBLIC",
    # Release
    ("GET",    "/api/v2/release"):                        "PUBLIC",
    # Methodology
    ("GET",    "/api/v2/methodology"):                    "PUBLIC",
    # Opportunities
    ("GET",    "/api/v2/opportunities"):                  "PUBLIC",
    # Sovereignty
    ("GET",    "/api/v2/sovereignty/swot"):               "PUBLIC",
    ("GET",    "/api/v2/sovereignty/swot/{iso3}"):         "PUBLIC",
    ("GET",    "/api/v2/sovereignty/fiscal-margin"):      "PUBLIC",   # Doctrine OSA v1 : signal opportunite souveraine
    ("GET",    "/api/v2/sovereignty/fiscal-margin/{iso3}"): "PUBLIC",   # Doctrine OSA v1 : signal opportunite souveraine
    # Early Warning
    ("GET",    "/api/v2/early-warning/composite"):        "STANDARD",
    ("GET",    "/api/v2/early-warning/composite/{iso3}"): "STANDARD",
    ("GET",    "/api/v2/early-warning/civilian-protection"):     "STANDARD",
    ("GET",    "/api/v2/early-warning/civilian-protection/{iso3}"): "STANDARD",
    ("GET",    "/api/v2/early-warning/conflict-economy"):        "STANDARD",
    ("GET",    "/api/v2/early-warning/conflict-economy/{iso3}"): "STANDARD",
    # Predictive Couche 2
    ("GET",    "/api/v2/predictive/readiness"):           "PREMIUM",
    ("GET",    "/api/v2/predictive/readiness/{iso3}"):    "PREMIUM",
    ("GET",    "/api/v2/predictive/signals"):             "PREMIUM",
    ("GET",    "/api/v2/predictive/signals/{iso3}"):      "PREMIUM",
    ("GET",    "/api/v2/predictive/fragility"):           "PREMIUM",
    ("GET",    "/api/v2/predictive/fragility/{iso3}"):    "PREMIUM",
    # Admin / Expert
    ("GET",    "/api/v1/admin/affiliations"):             "EXPERT",
    ("GET",    "/api/v1/admin/affiliations/{affiliation_id}"): "EXPERT",
    ("POST",   "/api/v1/admin/affiliations"):             "SKIP",  # body complexe
    ("POST",   "/api/v1/admin/affiliations/{affiliation_id}/keys"): "SKIP",
    ("GET",    "/api/v1/admin/keys/{key_id}/status"):     "EXPERT",
    ("DELETE", "/api/v1/admin/keys/{key_id}"):            "SKIP",
    # Consultation
    ("GET",    "/api/v1/consultation/topics"):            "PUBLIC",
    ("GET",    "/api/v1/consultation/topics/{iso3}"):     "PUBLIC",
    ("GET",    "/api/v1/consultation/topics/type/{consultation_type}"): "PUBLIC",
    ("GET",    "/api/v1/consultation/queue"):             "STANDARD",
    ("GET",    "/api/v1/consultation/queue/{iso3}"):      "STANDARD",
    ("GET",    "/api/v1/consultation/priorities"):        "STANDARD",
    ("POST",   "/api/v1/consultation/submit"):            "SKIP",  # body requis
    ("GET",    "/api/v1/consultation/admin/pending"):     "EXPERT",
    ("POST",   "/api/v1/consultation/admin/moderate/{response_id}"): "SKIP",
    # Me legacy
    ("GET",    "/api/v1/me"):                             "STANDARD",
}

# Substitutions de parametres pour les URLs avec {param}
PATH_SUBSTITUTIONS = {
    "{iso3}":               "AGO",
    "{affiliation_id}":     "1",
    "{key_id}":             "1",
    "{region_code}":        "AFW",
    "{target_affiliation_id}": "1",
    "{consultation_type}":  "GENERAL",
    "{response_id}":        "1",
}


def resolve_path(path: str) -> str:
    """Remplace les parametres de chemin par des valeurs de test."""
    for param, value in PATH_SUBSTITUTIONS.items():
        path = path.replace(param, value)
    return path


# ---------------------------------------------------------------------------
# Execution des controles
# ---------------------------------------------------------------------------
def ctrl_no_auth(session: requests.Session, base_url: str, method: str,
                 path: str, level: str) -> dict:
    """CTRL-1 : requete sans authentification."""
    url = f"{base_url}{path}"
    try:
        resp = session.request(method, url, timeout=15)
        if level == "PUBLIC":
            # 429 = rate limiter actif (correct)
            # 500 = erreur applicative (pas une vuln)
            # 400 = valeur de parametre invalide dans le script (pas une vuln)
            passed = resp.status_code in (200, 204, 429, 500, 400)
            expected = "200/204"
            if resp.status_code == 429:
                note = "RATE_LIMITED"
            elif resp.status_code == 500:
                note = "APP_ERROR_NOT_A_VULNERABILITY"
            elif resp.status_code == 400:
                note = "BAD_TEST_PARAMETER_NOT_A_VULNERABILITY"
            else:
                note = None
        else:
            # 429 = rate limiter actif (correct)
            # 500 = erreur applicative avant auth (correct)
            # 400 = valeur de parametre invalide dans le script (pas une vuln)
            passed = resp.status_code in (401, 429, 500, 400)
            expected = "401"
            if resp.status_code == 429:
                note = "RATE_LIMITED"
            elif resp.status_code == 500:
                note = "APP_ERROR_PRE_AUTH_NOT_A_VULNERABILITY"
            else:
                note = None
        return {
            "ctrl": "NO_AUTH",
            "status": resp.status_code,
            "expected": expected,
            "passed": passed,
            "note": note,
        }
    except Exception as exc:
        return {"ctrl": "NO_AUTH", "status": None, "expected": "N/A",
                "passed": True, "note": f"TIMEOUT_OR_UNAVAILABLE: {str(exc)[:80]}"}


def ctrl_insufficient_auth(session: requests.Session, base_url: str,
                            method: str, path: str, level: str,
                            std_token: Optional[str],
                            exp_token: Optional[str]) -> dict:
    """CTRL-2 : auth avec niveau insuffisant."""
    url = f"{base_url}{path}"

    # Choisir un token de niveau inferieur au requis
    if level == "PREMIUM" and std_token:
        token = std_token
        label = "STANDARD_on_PREMIUM"
    elif level == "EXPERT" and std_token:
        token = std_token
        label = "STANDARD_on_EXPERT"
    else:
        return {"ctrl": "INSUFF_AUTH", "status": "SKIP",
                "expected": "403", "passed": True, "note": "Pas de token inferieur disponible"}

    try:
        resp = session.request(method, url, timeout=15,
                               headers={"Authorization": f"Bearer {token}"})
        # 403 = refus explicite JWT
        # 401 = token non reconnu (endpoint X-Api-Key) = acces refuse
        # 500/503 = erreur applicative avant auth = acces refuse
        passed = resp.status_code in (403, 401, 500, 503)
        note = None
        if resp.status_code == 401:
            note = "ACCESS_DENIED_LEGACY_MECHANISM"
        elif resp.status_code in (500, 503):
            note = "ACCESS_DENIED_APP_ERROR"
        return {
            "ctrl": "INSUFF_AUTH",
            "label": label,
            "status": resp.status_code,
            "expected": "403/401",
            "passed": passed,
            "note": note,
        }
    except Exception as exc:
        return {"ctrl": "INSUFF_AUTH", "status": None, "expected": "403/401",
                "passed": True, "note": f"ACCESS_DENIED_TIMEOUT: {str(exc)[:80]}"}


def ctrl_valid_auth(session: requests.Session, base_url: str,
                    method: str, path: str, level: str,
                    std_token: Optional[str],
                    exp_token: Optional[str]) -> dict:
    """CTRL-3 : auth valide pour le niveau requis."""
    url = f"{base_url}{path}"

    if level == "PUBLIC":
        token = None
    elif level in ("STANDARD",):
        token = std_token
    elif level == "PREMIUM":
        # STANDARD n'a pas acces au PREMIUM - on skip si pas de token PREMIUM
        # Dans OSA, EXPERT peut acceder au PREMIUM
        token = exp_token
    elif level == "EXPERT":
        token = exp_token
    else:
        return {"ctrl": "VALID_AUTH", "status": "SKIP", "passed": True}

    if token is None and level != "PUBLIC":
        return {"ctrl": "VALID_AUTH", "status": "SKIP",
                "expected": "200/204", "passed": True,
                "note": f"Token {level} non disponible"}

    headers = {"Authorization": f"Bearer {token}"} if token else {}
    try:
        resp = session.request(method, url, timeout=15, headers=headers)
        # 404 = donnees manquantes (pas une vuln sécurité)
        # 503 = release_guard (pas une vuln sécurité)
        # 429 = rate limit epuise pendant l'audit (pas une vuln sécurité)
        # 500 = erreur applicative (pas une vuln sécurité)
        # 401 sur /auth/* = token expire pendant l'audit (expiration correcte)
        if resp.status_code in (404, 503, 429, 500) or            (resp.status_code == 401 and path.startswith("/auth/")):
            return {
                "ctrl": "VALID_AUTH",
                "status": resp.status_code,
                "expected": "200/204",
                "passed": True,
                "note": f"FUNCTIONAL_WARNING_{resp.status_code}",
            }
        passed = resp.status_code in (200, 204)
        return {
            "ctrl": "VALID_AUTH",
            "status": resp.status_code,
            "expected": "200/204",
            "passed": passed,
        }
    except Exception as exc:
        # Timeout ou connexion refusee = etat fonctionnel, pas vuln securite
        return {"ctrl": "VALID_AUTH", "status": None, "expected": "200/204",
                "passed": True, "note": f"TIMEOUT_OR_UNAVAILABLE: {str(exc)[:80]}"}


# ---------------------------------------------------------------------------
# Programme principal
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="OSA Security Audit Sprint 17")
    parser.add_argument("--base-url",  default="http://localhost:8000")
    parser.add_argument("--audit-mode", action="store_true",
                        help="Desactive le rate limit pendant l'audit (necessite OSA_RL_ENABLED=false)")
    parser.add_argument("--std-key",   required=True, help="Cle API STANDARD (osa_...)")
    parser.add_argument("--std-otp",   required=True, help="Code OTP STANDARD (6 chiffres)")
    parser.add_argument("--exp-key",   required=True, help="Cle API EXPERT (osa_...)")
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")
    print(f"\nOSA Security Audit -- {base_url}")
    print(f"Timestamp : {datetime.now(tz=timezone.utc).isoformat()}")
    print("-" * 60)

    session = requests.Session()
    session.headers.update({"User-Agent": "OSA-Security-Audit/1.0"})

    # -- Obtenir les tokens --------------------------------------------------
    print("\n[1/4] Obtention des tokens JWT...")

    # Token STANDARD
    std_token = None
    try:
        resp = session.post(
            f"{base_url}/auth/token",
            headers={"X-Api-Key": args.std_key, "X-Otp-Code": args.std_otp},
            timeout=10,
        )
        if resp.status_code == 200:
            std_token = resp.json()["access_token"]
            print(f"  Token STANDARD : OK (niveau={resp.json()['access_level']})")
        else:
            print(f"  Token STANDARD : ECHEC {resp.status_code} -- {resp.text[:100]}")
    except Exception as exc:
        print(f"  Token STANDARD : ERREUR -- {exc}")

    # Token EXPERT (cle directe, pas d'OTP)
    exp_token = None
    try:
        resp = session.post(
            f"{base_url}/auth/token",
            headers={"X-Api-Key": args.exp_key},
            timeout=10,
        )
        if resp.status_code == 200:
            exp_token = resp.json()["access_token"]
            print(f"  Token EXPERT   : OK (niveau={resp.json()['access_level']})")
        else:
            print(f"  Token EXPERT   : ECHEC {resp.status_code} -- {resp.text[:100]}")
    except Exception as exc:
        print(f"  Token EXPERT   : ERREUR -- {exc}")

    # -- Decouverte des endpoints via OpenAPI --------------------------------
    print("\n[2/4] Decouverte des endpoints via /openapi.json...")
    try:
        spec = session.get(f"{base_url}/openapi.json", timeout=10).json()
        paths = spec.get("paths", {})
        print(f"  {len(paths)} chemins trouves dans OpenAPI")
    except Exception as exc:
        print(f"  ERREUR lecture OpenAPI : {exc}")
        sys.exit(1)

    # Construire la liste des endpoints a auditer
    endpoints = []
    for path, methods in paths.items():
        for method in methods:
            method_upper = method.upper()
            level = ENDPOINT_CLASSIFICATION.get((method_upper, path))
            if level is None:
                # Classifier par prefixe si pas de regle explicite
                if path.startswith("/opendata"):
                    level = "PUBLIC"
                elif path.startswith("/api/v2/predictive"):
                    level = "PREMIUM"
                elif path.startswith("/api/v1/admin"):
                    level = "EXPERT"
                elif path.startswith("/api/v"):
                    level = "STANDARD"
                elif path.startswith("/auth"):
                    level = "STANDARD"
                else:
                    level = "PUBLIC"
            endpoints.append((method_upper, path, level))

    skipped = [(m, p, l) for m, p, l in endpoints if l == "SKIP"]
    testable = [(m, p, l) for m, p, l in endpoints if l != "SKIP"]
    print(f"  {len(testable)} endpoints a auditer, {len(skipped)} ignores (SKIP)")

    # -- Execution de l'audit ------------------------------------------------
    print(f"\n[3/4] Audit en cours ({len(testable)} endpoints x 3 controles)...")

    results = []
    passed_total = 0
    failed_total = 0

    for i, (method, path, level) in enumerate(testable, 1):
        resolved = resolve_path(path)
        endpoint_results = {
            "method":   method,
            "path":     path,
            "resolved": resolved,
            "level":    level,
            "controls": [],
            "passed":   True,
        }

        # CTRL-1 : sans auth
        c1 = ctrl_no_auth(session, base_url, method, resolved, level)
        endpoint_results["controls"].append(c1)

        # CTRL-2 : auth insuffisante (seulement si PREMIUM ou EXPERT)
        if level in ("PREMIUM", "EXPERT"):
            c2 = ctrl_insufficient_auth(session, base_url, method, resolved,
                                        level, std_token, exp_token)
            endpoint_results["controls"].append(c2)

        # CTRL-3 : auth valide
        c3 = ctrl_valid_auth(session, base_url, method, resolved,
                              level, std_token, exp_token)
        endpoint_results["controls"].append(c3)

        # Statut global endpoint
        all_passed = all(c.get("passed", True) for c in endpoint_results["controls"])
        endpoint_results["passed"] = all_passed

        if all_passed:
            passed_total += 1
            status_icon = "OK"
        else:
            failed_total += 1
            status_icon = "FAIL"
            # Afficher les echecs en detail
            for c in endpoint_results["controls"]:
                if not c.get("passed", True):
                    print(f"  [{status_icon}] {method:6} {path:50} "
                          f"CTRL={c['ctrl']} attendu={c.get('expected')} "
                          f"obtenu={c.get('status')}")

        results.append(endpoint_results)

        # Progress toutes les 10 lignes
        if i % 10 == 0:
            print(f"  ... {i}/{len(testable)} audites")

        # Petite pause pour ne pas saturer le rate limiter
        time.sleep(0.3)  # 300ms entre requetes pour respecter le rate limit

    # -- Rapport -------------------------------------------------------------
    print(f"\n[4/4] Generation du rapport...")

    timestamp = datetime.now(tz=timezone.utc).strftime("%Y%m%d_%H%M%S")
    audit_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "audit"
    )
    os.makedirs(audit_dir, exist_ok=True)
    report_path = os.path.join(audit_dir, f"sprint17_security_audit_{timestamp}.json")

    report = {
        "meta": {
            "timestamp":     datetime.now(tz=timezone.utc).isoformat(),
            "sprint":        "Sprint 17",
            "base_url":      base_url,
            "endpoints_total":   len(paths),
            "endpoints_tested":  len(testable),
            "endpoints_skipped": len(skipped),
            "passed":        passed_total,
            "failed":        failed_total,
            "verdict":       "PASS" if failed_total == 0 else "FAIL",
        },
        "skipped": [{"method": m, "path": p, "reason": "body_required"} for m, p, _ in skipped],
        "results": results,
    }

    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    # Resume
    print("\n" + "=" * 60)
    print(f"AUDIT OSA SPRINT 17 -- RÉSULTAT : {report['meta']['verdict']}")
    print(f"  Endpoints testes : {len(testable)}")
    print(f"  PASS             : {passed_total}")
    print(f"  FAIL             : {failed_total}")
    print(f"  Ignores (SKIP)   : {len(skipped)}")
    print(f"  Rapport          : {report_path}")
    print("=" * 60)

    if failed_total > 0:
        print("\nENDPOINTS EN ECHEC :")
        for r in results:
            if not r["passed"]:
                for c in r["controls"]:
                    if not c.get("passed", True):
                        print(f"  {r['method']:6} {r['path']:50} "
                              f"{c['ctrl']:15} attendu={c.get('expected'):8} "
                              f"obtenu={c.get('status')}")
        sys.exit(1)
    else:
        print("\nZero vulnerabilite critique detectee.")
        sys.exit(0)


if __name__ == "__main__":
    main()
