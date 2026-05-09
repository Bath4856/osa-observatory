# ============================================================
# OSA / ISA — PATCH P3 PRES + PTRA FAST
# Retest API des quick wins PRES + PTRA.
# ============================================================

import json
import time
from datetime import datetime
from pathlib import Path
import requests

OUTPUT_FILE = Path("mapping/activation/test_p3_pres_ptra_fast_results.json")
TIMEOUT = 45
RETRIES = 3

TESTS_WB = [
    ("PRES_OIL_RENTS",        "NY.GDP.PETR.RT.ZS", "ZAF"),
    ("PRES_GAS_RENTS",        "NY.GDP.NGAS.RT.ZS", "ZAF"),
    ("PRES_ENRG_USE_CAP",     "EG.USE.PCAP.KG.OE", "ZAF"),
    ("PRES_FOSSIL_RENTS_EIA", "NY.GDP.TOTL.RT.ZS", "ZAF"),
    ("PRES_RENEW_SHARE_FEC",  "EG.FEC.RNEW.ZS",    "ZAF"),
    ("PRES_WATER_AGRI",       "AG.LND.IRIG.AG.ZS", "ZAF"),
    ("PTRA_RD_PAVED",         "IS.ROD.PAVE.ZS",    "ZAF"),
    ("PTRA_RD_DENSITY",       "IS.ROD.DNST.K2",    "ZAF"),
    ("PTRA_LOG_LPI",          "LP.LPI.OVRL.XQ",    "ZAF"),
]

TESTS_MANUAL = [
    ("PTRA_RD_QUALITY", "WEF_GCI_MANUAL", "GCI_ROAD_QUALITY", "Série WEF/GCI manuelle ; rupture GCI3/GCI4 en 2018")
]


def wb_url(country: str, code: str) -> str:
    return f"https://api.worldbank.org/v2/country/{country}/indicator/{code}?format=json&per_page=100&mrv=10"


def test_wb(indicator: str, code: str, country: str) -> dict:
    url = wb_url(country, code)
    for attempt in range(1, RETRIES + 1):
        try:
            response = requests.get(url, timeout=TIMEOUT)
            if response.status_code != 200:
                return {"indicator": indicator, "provider": "WB", "source_code": code, "country": country, "status": "KO", "error": f"HTTP {response.status_code}", "url": url}
            payload = response.json()
            if not isinstance(payload, list) or len(payload) < 2:
                return {"indicator": indicator, "provider": "WB", "source_code": code, "country": country, "status": "KO", "error": "Payload WB invalide", "url": url}
            rows = payload[1] or []
            valid = [r for r in rows if r.get("value") is not None]
            if not valid:
                return {"indicator": indicator, "provider": "WB", "source_code": code, "country": country, "status": "WARN", "error": "Code valide mais aucune valeur récente sur pays test", "url": url}
            sample = valid[0]
            return {"indicator": indicator, "provider": "WB", "source_code": code, "country": country, "status": "OK", "year": sample.get("date"), "value": sample.get("value"), "url": url}
        except requests.exceptions.Timeout:
            if attempt < RETRIES:
                time.sleep(2 * attempt)
                continue
            return {"indicator": indicator, "provider": "WB", "source_code": code, "country": country, "status": "KO", "error": "Timeout après retries", "url": url}
        except Exception as exc:
            return {"indicator": indicator, "provider": "WB", "source_code": code, "country": country, "status": "KO", "error": str(exc), "url": url}


def main():
    print("════════════════════════════════════════════════════════════")
    print(f" OSA — Retest P3 PRES/PTRA   {datetime.now():%d/%m/%Y %H:%M}")
    print("════════════════════════════════════════════════════════════")
    results = []
    for indicator, code, country in TESTS_WB:
        result = test_wb(indicator, code, country)
        results.append(result)
        if result["status"] == "OK":
            print(f"✓ {indicator:<26} OK {result.get('year')} → {result.get('value')}")
        elif result["status"] == "WARN":
            print(f"⚠ {indicator:<26} WARN — {result.get('error')}")
        else:
            print(f"✗ {indicator:<26} KO — {result.get('error')}")
    for indicator, provider, code, note in TESTS_MANUAL:
        result = {"indicator": indicator, "provider": provider, "source_code": code, "status": "WARN", "error": note, "url": "manual://wef/gci"}
        results.append(result)
        print(f"⚠ {indicator:<26} WARN — {note}")
    summary = {"ok": sum(1 for r in results if r["status"] == "OK"), "warn": sum(1 for r in results if r["status"] == "WARN"), "ko": sum(1 for r in results if r["status"] == "KO"), "total": len(results)}
    print("────────────────────────────────────────────────────────────")
    print(f"OK      : {summary['ok']}")
    print(f"Alertes : {summary['warn']}")
    print(f"Échecs  : {summary['ko']}")
    print(f"Total   : {summary['total']}")
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(json.dumps({"timestamp": datetime.now().isoformat(), "summary": summary, "results": results}, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Résultats exportés → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
