# ============================================================
# OSA / ISA — P5 ZERO ORPHANS VALIDATION
# Validation runtime des 13 derniers orphelins
# ============================================================

import json
import time
from datetime import datetime
from pathlib import Path

import requests

OUTPUT_FILE = Path("mapping/activation/test_p5_zero_orphans_results.json")
TIMEOUT = 45
RETRIES = 3

TESTS = [
    # P5A PMIL
    {"lot": "P5A", "indicator": "MIL_EXP", "provider": "WB", "code": "MS.MIL.XPND.GD.ZS", "country": "ZAF"},
    {"lot": "P5A", "indicator": "MIL_EXP_PCT", "provider": "WB", "code": "MS.MIL.XPND.GD.ZS", "country": "ZAF"},
    {"lot": "P5A", "indicator": "MIL_EXP_PC", "provider": "WB", "code": "MS.MIL.XPND.CD", "country": "ZAF"},
    {"lot": "P5A", "indicator": "PMIL_HOMICIDE_RATE", "provider": "WB", "code": "VC.IHR.PSRC.P5", "country": "ZAF"},
    {"lot": "P5A", "indicator": "MIL_CYB", "provider": "ITU", "code": "GCI_CYBER", "country": None},

    # P5B PHUM
    {"lot": "P5B", "indicator": "HUM_POP", "provider": "WB", "code": "SL.TLF.TOTL.IN", "country": "ZAF"},
    {"lot": "P5B", "indicator": "HUM_FOO", "provider": "WB", "code": "SN.ITK.DEFC.ZS", "country": "ZAF"},
    {"lot": "P5B", "indicator": "HUM_DIG", "provider": "WB", "code": "SE.ADT.LITR.ZS", "country": "ZAF"},
    {"lot": "P5B", "indicator": "HUM_SOC", "provider": "OSA", "code": "HUM_SOC_COMPOSITE", "country": None},
    {"lot": "P5B", "indicator": "HUM_RES", "provider": "OSA", "code": "HUM_RES_COMPOSITE", "country": None},

    # P5C HYBRIDS
    {"lot": "P5C", "indicator": "ECO_AGR", "provider": "WB", "code": "AG.PRD.FOOD.XD", "country": "ZAF"},
    {"lot": "P5C", "indicator": "NUM_CYB", "provider": "ITU", "code": "GCI_CYBER", "country": None},
    {"lot": "P5C", "indicator": "PTRA_PORT_CAP", "provider": "WB", "code": "IS.SHP.GOOD.TU", "country": "ZAF"},
]


def wb_url(country: str, code: str) -> str:
    return f"https://api.worldbank.org/v2/country/{country}/indicator/{code}?format=json&per_page=100&mrv=10"


def test_wb(item: dict) -> dict:
    url = wb_url(item["country"], item["code"])
    for attempt in range(1, RETRIES + 1):
        try:
            r = requests.get(url, timeout=TIMEOUT)
            if r.status_code != 200:
                return {**item, "status": "KO", "error": f"HTTP {r.status_code}", "url": url}
            payload = r.json()
            if not isinstance(payload, list) or len(payload) < 2:
                return {**item, "status": "KO", "error": "Payload WB invalide", "url": url}
            rows = payload[1] or []
            valid = [x for x in rows if x.get("value") is not None]
            if not valid:
                return {**item, "status": "WARN", "error": "Code valide mais aucune valeur récente sur pays test", "url": url}
            sample = valid[0]
            return {**item, "status": "OK", "year": sample.get("date"), "value": sample.get("value"), "url": url}
        except requests.exceptions.Timeout:
            if attempt < RETRIES:
                time.sleep(2 * attempt)
                continue
            return {**item, "status": "KO", "error": "Timeout après retries", "url": url}
        except Exception as exc:
            return {**item, "status": "KO", "error": str(exc), "url": url}


def test_manual(item: dict) -> dict:
    return {**item, "status": "WARN", "error": f"{item['provider']} source manuelle/interne ; activation runtime non API WB"}


def run_item(item: dict) -> dict:
    if item["provider"] == "WB":
        return test_wb(item)
    return test_manual(item)


def main():
    print("════════════════════════════════════════════════════════════")
    print(f" OSA — P5 ZERO ORPHANS   {datetime.now():%d/%m/%Y %H:%M}")
    print("════════════════════════════════════════════════════════════")

    results = []
    for item in TESTS:
        result = run_item(item)
        results.append(result)
        status = result["status"]
        prefix = "✓" if status == "OK" else ("⚠" if status == "WARN" else "✗")
        if status == "OK":
            print(f"{prefix} {item['lot']} {item['indicator']:<22} OK   {result.get('year')} → {result.get('value')}")
        else:
            print(f"{prefix} {item['lot']} {item['indicator']:<22} {status} — {result.get('error')}")

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
    OUTPUT_FILE.write_text(json.dumps({"timestamp": datetime.now().isoformat(), "summary": summary, "results": results}, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Résultats exportés → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
