# ============================================================
# OSA / ISA — PATCH P2 ORPHANS WB FAST
# Retest API des 10 orphelins WB rapides
# ============================================================

import json
import time
from datetime import datetime
from pathlib import Path

import requests


OUTPUT_FILE = Path("mapping/activation/test_p2_orphans_wb_fast_results.json")
TIMEOUT = 45
RETRIES = 3

TESTS = [
    ("PNUM_INTERNET_USERS",       "IT.NET.USER.ZS",    "ZAF"),
    ("PNUM_BROADBAND_FIXED",      "IT.NET.BBND.P2",    "ZAF"),
    ("PNUM_MOBILE_SUBSCRIPTIONS", "IT.CEL.SETS.P2",    "ZAF"),
    ("PNUM_SECURE_SERVERS",       "IT.NET.SECR.P6",    "ZAF"),

    ("PMIL_DEF_BUDGET_GDP",       "MS.MIL.XPND.GD.ZS", "ZAF"),
    ("PMIL_DEF_BUDGET_GOV",       "MS.MIL.XPND.ZS",    "ZAF"),
    ("PMIL_ARMED_FORCES",         "MS.MIL.TOTL.P1",    "ZAF"),

    ("PTRA_AIR_PASSENGERS",       "IS.AIR.PSGR",       "ZAF"),
    ("PTRA_AIR_CARGO",            "IS.AIR.GOOD.MT.K1", "ZAF"),
    ("PTRA_AIR_AIRPORTS",         "IS.AIR.DPRT",       "ZAF"),
]


def wb_url(country: str, code: str) -> str:
    return (
        f"https://api.worldbank.org/v2/country/{country}/indicator/{code}"
        "?format=json&per_page=100&mrv=10"
    )


def test_wb(indicator: str, code: str, country: str) -> dict:
    url = wb_url(country, code)

    for attempt in range(1, RETRIES + 1):
        try:
            response = requests.get(url, timeout=TIMEOUT)

            if response.status_code != 200:
                return {
                    "indicator": indicator,
                    "source_code": code,
                    "country": country,
                    "status": "KO",
                    "error": f"HTTP {response.status_code}",
                    "url": url,
                }

            payload = response.json()

            if not isinstance(payload, list) or len(payload) < 2:
                return {
                    "indicator": indicator,
                    "source_code": code,
                    "country": country,
                    "status": "KO",
                    "error": "Payload WB invalide",
                    "url": url,
                }

            rows = payload[1] or []
            valid = [r for r in rows if r.get("value") is not None]

            if not valid:
                return {
                    "indicator": indicator,
                    "source_code": code,
                    "country": country,
                    "status": "WARN",
                    "error": "Code valide mais aucune valeur récente sur pays test",
                    "url": url,
                }

            sample = valid[0]
            return {
                "indicator": indicator,
                "source_code": code,
                "country": country,
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
                "indicator": indicator,
                "source_code": code,
                "country": country,
                "status": "KO",
                "error": "Timeout après retries",
                "url": url,
            }

        except Exception as exc:
            return {
                "indicator": indicator,
                "source_code": code,
                "country": country,
                "status": "KO",
                "error": str(exc),
                "url": url,
            }


def main():
    print("════════════════════════════════════════════════════════════")
    print(f" OSA — Retest P2 orphelins WB   {datetime.now():%d/%m/%Y %H:%M}")
    print("════════════════════════════════════════════════════════════")

    results = []

    for indicator, code, country in TESTS:
        result = test_wb(indicator, code, country)
        results.append(result)

        if result["status"] == "OK":
            print(
                f"✓ {indicator:<30} OK "
                f"{result.get('year')} → {result.get('value')}"
            )
        elif result["status"] == "WARN":
            print(f"⚠ {indicator:<30} WARN — {result.get('error')}")
        else:
            print(f"✗ {indicator:<30} KO — {result.get('error')}")

    summary = {
        "ok": sum(1 for r in results if r["status"] == "OK"),
        "warn": sum(1 for r in results if r["status"] == "WARN"),
        "ko": sum(1 for r in results if r["status"] == "KO"),
        "total": len(results),
    }

    print("────────────────────────────────────────────────────────────")
    print(f"OK      : {summary['ok']}")
    print(f"Alertes : {summary['warn']}")
    print(f"Échecs  : {summary['ko']}")
    print(f"Total   : {summary['total']}")

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(
        json.dumps(
            {
                "timestamp": datetime.now().isoformat(),
                "summary": summary,
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