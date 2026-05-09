"""
test_apis_p1.py
Vérification des 18 sources API — Indicateurs P1
Exécution : python test_apis_p1.py
Résultat   : rapport console + fichier test_apis_p1_results.json
"""

import urllib.request
import urllib.error
import json
import time
import sys
from datetime import datetime

TIMEOUT = 12

TESTS = [
    {
        "indicator_code": "ECO_UNE",
        "mapping_key": "ILO_UNE_DEAP_RT_A",
        "source": "ILO ILOSTAT",
        "api_url": "https://rplumber.ilo.org/data/indicator/?id=UNE_DEAP_RT_A&ref_area=FRA&timefrom=2020&type=label&format=json",
        "check": lambda d: isinstance(d, dict) and "dataSets" in d or isinstance(d, list) and len(d) > 0,
        "note": "API REST ILO — retourne JSON avec clé 'dataSets'",
        "alert": "",
    },
    {
        "indicator_code": "PNUM_SECURE_SERVERS",
        "mapping_key": "WB_IT_NET_SECR",
        "source": "Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/IT.NET.SECR?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2 and isinstance(d[1], list),
        "note": "API WB — retourne [metadata, [records]]",
        "alert": "",
    },
    {
        "indicator_code": "PNUM_MOBILE_SUBSCRIPTIONS",
        "mapping_key": "WB_IT_CEL_SETS_P2",
        "source": "Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/IT.CEL.SETS.P2?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2 and isinstance(d[1], list),
        "note": "API WB — retourne [metadata, [records]]",
        "alert": "",
    },
    {
        "indicator_code": "PNUM_INTERNET_USERS",
        "mapping_key": "WB_IT_NET_USER_ZS",
        "source": "Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/IT.NET.USER.ZS?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2 and isinstance(d[1], list),
        "note": "API WB standard",
        "alert": "",
    },
    {
        "indicator_code": "PNUM_BROADBAND_FIXED",
        "mapping_key": "ITU_BB_FIXED_SUBS_P100",
        "source": "ITU (via Banque mondiale)",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/IT.NET.BBND.P2?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Fallback WB pour haut débit fixe ITU (IT.NET.BBND.P2)",
        "alert": "Source primaire ITU nécessite inscription manuelle sur https://www.itu.int",
    },
    {
        "indicator_code": "PRES_RENEW_SHARE_FEC",
        "mapping_key": "IEA_RENEW_SHARE_FEC",
        "source": "IEA (via Banque mondiale SE4ALL)",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/EG.FEC.RNEW.ZS?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Proxy WB (EG.FEC.RNEW.ZS) = part renouvelables dans FEC. Source IEA directe nécessite abonnement.",
        "alert": "Accès IEA direct peut nécessiter abonnement — proxy WB recommandé en remplacement",
    },
    {
        "indicator_code": "PRES_FOSSIL_RENTS_EIA",
        "mapping_key": "WB_NY_GDP_TOTL_RT_ZS",
        "source": "Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/NY.GDP.TOTL.RT.ZS?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Rentes fossiles totales % PIB",
        "alert": "",
    },
    {
        "indicator_code": "PRES_WATER_FRESH",
        "mapping_key": "FAO_AQUASTAT_IRWR",
        "source": "FAO AQUASTAT",
        "api_url": "https://www.fao.org/aquastat/api/v1/data?indicatorId=4251&countryIso3=FRA&yearStart=2010&yearEnd=2022",
        "check": lambda d: isinstance(d, (dict, list)),
        "note": "API AQUASTAT — indicateur 4251 = ressources internes renouvelables",
        "alert": "Fréquence pluriannuelle — prévoir interpolation dans le pipeline",
    },
    {
        "indicator_code": "PRES_WATER_WITHDRAWAL",
        "mapping_key": "FAO_AQUASTAT_WITHDRAWAL",
        "source": "FAO AQUASTAT",
        "api_url": "https://www.fao.org/aquastat/api/v1/data?indicatorId=4153&countryIso3=FRA&yearStart=2010&yearEnd=2022",
        "check": lambda d: isinstance(d, (dict, list)),
        "note": "API AQUASTAT — indicateur 4153 = prélèvements totaux",
        "alert": "Fréquence pluriannuelle — prévoir interpolation dans le pipeline",
    },
    {
        "indicator_code": "PMIL_DEF_BUDGET_GDP",
        "mapping_key": "SIPRI_MILEX_GDP_SHARE",
        "source": "SIPRI (via Banque mondiale)",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/MS.MIL.XPND.GD.ZS?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Proxy WB pour dépenses militaires % PIB (source SIPRI). Téléchargement direct SIPRI sur sipri.org/databases/milex",
        "alert": "",
    },
    {
        "indicator_code": "PMIL_DEF_BUDGET_GOV",
        "mapping_key": "SIPRI_MILEX_GOV_SHARE",
        "source": "SIPRI (via Banque mondiale)",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/MS.MIL.XPND.ZS?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Proxy WB pour dépenses militaires % dépenses publiques. Téléchargement SIPRI recommandé pour séries complètes.",
        "alert": "",
    },
    {
        "indicator_code": "PMIL_ARMED_FORCES",
        "mapping_key": "WB_MS_MIL_TOTL_P1",
        "source": "Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/MS.MIL.TOTL.P1?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Forces armées % pop. active",
        "alert": "",
    },
    {
        "indicator_code": "PNUM_TERTIARY_ENROLL",
        "mapping_key": "UNESCO_ENRL_TERTIARY_GER",
        "source": "UNESCO UIS",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/SE.TER.ENRR?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Proxy WB (SE.TER.ENRR). Source directe UIS sur data.uis.unesco.org — nécessite clé API.",
        "alert": "API UIS directe nécessite inscription sur https://apiportal.uis.unesco.org/",
    },
    {
        "indicator_code": "PTRA_RD_QUALITY",
        "mapping_key": "WEF_GCI_INFRA_ROAD_QUALITY",
        "source": "WEF GCI",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/IQ.WEF.INFQ.XQ?format=json&mrv=3",
        "check": lambda d: isinstance(d, list),
        "note": "WEF GCI données non disponibles via API publique — téléchargement manuel sur weforum.org. Test proxy WB uniquement.",
        "alert": "Rupture de série GCI3/GCI4 en 2018 — documenter dans les métadonnées. Téléchargement manuel requis.",
    },
    {
        "indicator_code": "PTRA_AIR_AIRPORTS",
        "mapping_key": "WB_IS_AIR_DPRT",
        "source": "OACI / Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/IS.AIR.DPRT?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Départs aériens enregistrés",
        "alert": "",
    },
    {
        "indicator_code": "PRES_RENEW_CAP_IRENA",
        "mapping_key": "IRENA_RENEW_CAP_MW",
        "source": "IRENA",
        "api_url": "https://pxweb.irena.org/api/v1/en/IRENASTAT/Power%20Capacity%20and%20Generation/ELECCAP_2024_cycle2.px",
        "check": lambda d: isinstance(d, dict),
        "note": "API IRENA PxWeb — retourne métadonnées JSON du dataset capacité installée",
        "alert": "",
    },
    {
        "indicator_code": "PTRA_PORT_CONNECT",
        "mapping_key": "WB_IS_SHP_GCNW_XQ",
        "source": "CNUCED / Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/IS.SHP.GCNW.XQ?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Indice LSCI connectivité maritime",
        "alert": "",
    },
    {
        "indicator_code": "PRES_GAS_RENTS",
        "mapping_key": "WB_NY_GDP_NGAS_RT_ZS",
        "source": "Banque mondiale",
        "api_url": "https://api.worldbank.org/v2/country/FRA/indicator/NY.GDP.NGAS.RT.ZS?format=json&mrv=3",
        "check": lambda d: isinstance(d, list) and len(d) == 2,
        "note": "Rentes gaz naturel % PIB",
        "alert": "",
    },
]

# ── Helpers ──────────────────────────────────────────────────────────────────

RESET  = "\033[0m"
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
DIM    = "\033[2m"

def fetch(url, timeout=TIMEOUT):
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (mapping-verification-script/1.0)",
        "Accept": "application/json",
    })
    resp = urllib.request.urlopen(req, timeout=timeout)
    raw = resp.read()
    return resp.getcode(), json.loads(raw)

def run_tests():
    print(f"\n{BOLD}{'═'*72}{RESET}")
    print(f"{BOLD}  Vérification APIs — Indicateurs P1   {datetime.now().strftime('%d/%m/%Y %H:%M')}{RESET}")
    print(f"{BOLD}{'═'*72}{RESET}\n")

    results = []
    ok = warn = fail = 0

    for t in TESTS:
        code = t["indicator_code"]
        sys.stdout.write(f"  {DIM}{code:<32}{RESET} ")
        sys.stdout.flush()

        result = {
            "indicator_code": code,
            "mapping_key": t["mapping_key"],
            "source": t["source"],
            "api_url": t["api_url"],
            "note": t["note"],
            "alert": t["alert"],
            "status": None,
            "http_code": None,
            "data_valid": None,
            "sample": None,
            "error": None,
            "url_ok": False,
            "data_ok": False,
        }

        try:
            http_code, data = fetch(t["api_url"])
            result["http_code"] = http_code
            result["url_ok"] = True

            valid = False
            try:
                valid = t["check"](data)
            except Exception:
                pass

            result["data_valid"] = valid
            result["data_ok"] = valid

            # Sample value
            try:
                if isinstance(data, list) and len(data) == 2 and isinstance(data[1], list):
                    rec = next((r for r in data[1] if r.get("value") is not None), None)
                    if rec:
                        result["sample"] = f"{rec.get('date','?')} → {rec['value']}"
            except Exception:
                pass

            if valid:
                icon = f"{GREEN}✓ OK{RESET}"
                if t["alert"]:
                    icon = f"{YELLOW}✓ OK (alerte){RESET}"
                    warn += 1
                    result["status"] = "OK_ALERTE"
                else:
                    ok += 1
                    result["status"] = "OK"
                sample_str = f"  {DIM}ex: {result['sample']}{RESET}" if result["sample"] else ""
                print(f"{icon}{sample_str}")
            else:
                print(f"{YELLOW}⚠ Données inattendues (HTTP {http_code}){RESET}")
                warn += 1
                result["status"] = "WARN"

        except urllib.error.HTTPError as e:
            print(f"{RED}✗ HTTP {e.code}{RESET}")
            result["http_code"] = e.code
            result["error"] = f"HTTP {e.code}"
            result["status"] = "FAIL"
            fail += 1

        except urllib.error.URLError as e:
            print(f"{RED}✗ Connexion impossible — {e.reason}{RESET}")
            result["error"] = str(e.reason)
            result["status"] = "FAIL"
            fail += 1

        except Exception as e:
            print(f"{RED}✗ Erreur — {e}{RESET}")
            result["error"] = str(e)
            result["status"] = "FAIL"
            fail += 1

        if t["alert"] and result["status"] in ("OK", "OK_ALERTE"):
            print(f"    {YELLOW}⚠  {t['alert']}{RESET}")

        results.append(result)
        time.sleep(0.3)

    # ── Résumé ────────────────────────────────────────────────────────────────
    total = len(results)
    print(f"\n{BOLD}{'─'*72}{RESET}")
    print(f"{BOLD}  Résumé{RESET}")
    print(f"  {GREEN}✓ OK        : {ok}{RESET}")
    print(f"  {YELLOW}⚠ Alertes   : {warn}{RESET}")
    print(f"  {RED}✗ Échecs    : {fail}{RESET}")
    print(f"  Total       : {total}")

    if fail > 0:
        print(f"\n{BOLD}  Indicateurs en échec :{RESET}")
        for r in results:
            if r["status"] == "FAIL":
                print(f"  {RED}✗{RESET} {r['indicator_code']:<32} {r.get('error','?')}")

    if warn > 0:
        print(f"\n{BOLD}  Points d'attention :{RESET}")
        for r in results:
            if r["status"] in ("WARN", "OK_ALERTE") and r["alert"]:
                print(f"  {YELLOW}⚠{RESET} {r['indicator_code']:<32} {r['alert']}")

    # ── Export JSON ───────────────────────────────────────────────────────────
    output = {
        "run_date": datetime.now().isoformat(),
        "summary": {"ok": ok, "warn": warn, "fail": fail, "total": total},
        "results": results,
    }
    with open("test_apis_p1_results.json", "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n{DIM}  Résultats exportés → test_apis_p1_results.json{RESET}")
    print(f"{BOLD}{'═'*72}{RESET}\n")

    return output

if __name__ == "__main__":
    run_tests()
