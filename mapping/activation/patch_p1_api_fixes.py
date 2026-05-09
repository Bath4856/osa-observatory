# ============================================================
# OSA / ISA — PATCH P1 API FIXES
# Retest des 6 indicateurs P1 en échec
# ============================================================

import json
import time
from datetime import datetime
from pathlib import Path

import requests


OUTPUT_FILE = Path("mapping/activation/test_apis_p1_fixes_results.json")

TIMEOUT = 45
RETRIES = 3

TESTS = [
    {
        "indicator": "ECO_UNE",
        "provider": "WB",
        "source_code": "SL.UEM.TOTL.ZS",
        "country": "ZAF",
        "note": "Chômage total — proxy WB WDI",
    },
    {
        "indicator": "PRES_WATER_FRESH",
        "provider": "WB",
        "source_code": "ER.H2O.INTR.PC",
        "country": "ZAF",
        "note": "Ressources internes renouvelables en eau douce par habitant",
    },
    {
        "indicator": "PRES_WATER_WITHDRAWAL",
        "provider": "WB",
        "source_code": "ER.H2O.FWTL.ZS",
        "country": "ZAF",
        "note": "Prélèvements annuels eau douce % ressources internes",
    },
    {
        "indicator": "PNUM_TERTIARY_ENROLL",
        "provider": "WB",
        "source_code": "SE.TER.ENRR",
        "country": "ZAF",
        "note": "Scolarisation supérieur brute",
    },
    {
        "indicator": "PTRA_PORT_CONNECT",
        "provider": "WB",
        "source_code": "IS.SHP.GCNW.XQ",
        "country": "ZAF",
        "note": "Liner Shipping Connectivity Index — proxy WB",
    },
    {
        "indicator": "PRES_RENEW_CAP_IRENA",
        "provider": "IRENA",
        "source_code": "RENEW_CAP_MW",
        "country": None,
        "note": "IRENA CSV/manual — endpoint non testé comme API JSON WB",
    },
]


def wb_url(country: str, code: str) -> str:
    return (
        f"https://api.worldbank.org/v2/country/{country}/indicator/{code}"
        "?format=json&per_page=100&mrv=10"
    )


def test_world_bank(item: dict) -> dict:
    url = wb_url(item["country"], item["source_code"])

    for attempt in range(1, RETRIES + 1):
        try:
            r = requests.get(url, timeout=TIMEOUT)

            if r.status_code != 200:
                return {
                    **item,
                    "status": "KO",
                    "error": f"HTTP {r.status_code}",
                    "url": url,
                }

            payload = r.json()

            if not isinstance(payload, list) or len(payload) < 2:
                return {
                    **item,
                    "status": "KO",
                    "error": "Payload WB invalide",
                    "url": url,
                }

            rows = payload[1] or []
            valid = [x for x in rows if x.get("value") is not None]

            if not valid:
                return {
                    **item,
                    "status": "WARN",
                    "error": "Code valide mais aucune valeur récente sur pays test",
                    "url": url,
                }

            sample = valid[0]

            return {
                **item,
                "status": "OK",
                "year": sample.get("date"),
                "value": sample.get("value"),
                "url": url,
            }

        except requests.exceptions.Timeout:
            if attempt < RETRIES:
                time.sleep(2 * attempt)
                continue
            return {
                **item,
                "status": "KO",
                "error": "Timeout après retries",
                "url": url,
            }

        except Exception as e:
            return {
                **item,
                "status": "KO",
                "error": str(e),
                "url": url,
            }


def test_irena(item: dict) -> dict:
    return {
        **item,
        "status": "WARN",
        "error": "Source IRENA à traiter en CSV/manual, pas en API WB",
        "url": "https://www.irena.org/Data/Downloads/IRENASTAT",
    }


def run_test(item: dict) -> dict:
    if item["provider"] == "WB":
        return test_world_bank(item)

    if item["provider"] == "IRENA":
        return test_irena(item)

    return {
        **item,
        "status": "KO",
        "error": "Provider non supporté dans ce patch",
    }


def main():
    print("════════════════════════════════════════════════════════════")
    print(f" OSA — Retest API P1 fixes   {datetime.now():%d/%m/%Y %H:%M}")
    print("════════════════════════════════════════════════════════════")

    results = []

    for item in TESTS:
        result = run_test(item)
        results.append(result)

        status = result["status"]

        if status == "OK":
            print(
                f"✓ {item['indicator']:<28} OK "
                f"{result.get('year')} → {result.get('value')}"
            )
        elif status == "WARN":
            print(f"⚠ {item['indicator']:<28} WARN — {result.get('error')}")
        else:
            print(f"✗ {item['indicator']:<28} KO — {result.get('error')}")

    ok = sum(1 for r in results if r["status"] == "OK")
    warn = sum(1 for r in results if r["status"] == "WARN")
    ko = sum(1 for r in results if r["status"] == "KO")

    print("────────────────────────────────────────────────────────────")
    print(f"OK      : {ok}")
    print(f"Alertes : {warn}")
    print(f"Échecs  : {ko}")
    print(f"Total   : {len(results)}")

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(
        json.dumps(
            {
                "timestamp": datetime.now().isoformat(),
                "summary": {"ok": ok, "warn": warn, "ko": ko, "total": len(results)},
                "results": results,
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    print(f"Résultats exportés → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()