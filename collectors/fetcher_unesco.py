"""OSA fetcher_unesco — UNESCO UIS API publique (sans cle)"""
from __future__ import annotations
import requests
from fetcher_base import AFRICAN_ISO3, SAMPLE_ISO3, BaseFetcher

UNESCO_BASE = "https://api.uis.unesco.org/api/public/data/indicators"

UNESCO_INDICATOR_MAP = {
    "HUM_LIT": {"uis_code":"CR.1",          "name_fr":"Taux alphabetisation adultes 15+",       "unit_code":"PERCENT",  "direction":"+", "multiplier":1.0, "notes":"UNESCO CR.1 — sans cle. 2000-2024."},
    "HUM_EDU": {"uis_code":"GER.3",          "name_fr":"Taux brut scolarisation tertiaire",      "unit_code":"PERCENT",  "direction":"+", "multiplier":1.0, "notes":"UNESCO GER.3 — sans cle. 1994-2024."},
    "HUM_SCO": {"uis_code":"GER.2",          "name_fr":"Taux brut scolarisation secondaire",     "unit_code":"PERCENT",  "direction":"+", "multiplier":1.0, "notes":"UNESCO GER.2 — sans cle. 1994-2024."},
    "HUM_EDG": {"uis_code":"XGDP.1.FSGOV",  "name_fr":"Depenses education % PIB",              "unit_code":"PERCENT",  "direction":"+", "multiplier":1.0, "notes":"UNESCO XGDP — sans cle. 1971-2024."},
}

class UNESCOFetcher(BaseFetcher):
    PROVIDER_CODE  = "UNESCO"
    ENDPOINT_CODE  = "UNESCO_UIS_INDICATOR"
    SOURCE_CODE    = "UNESCO"

    def connect(self):
        self.log.info("UNESCO -- verification API...")
        r = requests.get(f"{UNESCO_BASE}?indicator=CR.1&countryCode=MAR&format=json", timeout=10)
        if r.status_code != 200:
            raise ConnectionError(f"UNESCO API HTTP {r.status_code}")
        self.log.info("UNESCO -- API accessible (sans cle)")
        super().connect()

    def fetch_indicator(self, osa_code, cfg, countries, year_from, year_to):
        records = []
        uis_code = cfg["uis_code"]
        params = f"?indicator={uis_code}&format=json"
        for iso3 in countries:
            params += f"&countryCode={iso3}"
        url = f"{UNESCO_BASE}{params}"
        try:
            r = requests.get(url, timeout=30)
            if r.status_code != 200:
                self.log.warning("UNESCO %s HTTP %s", uis_code, r.status_code)
                return records
            data = r.json()
            for rec in data.get("records", []):
                iso3 = rec.get("geoUnit","").upper()
                year = rec.get("year")
                value = rec.get("value")
                if iso3 not in countries or value is None:
                    continue
                if year < year_from or year > year_to:
                    continue
                records.append({"country_iso3":iso3, "indicator_code":osa_code,
                    "year":year, "value":float(value)*cfg["multiplier"],
                    "unit_code":cfg["unit_code"], "provider_code":self.PROVIDER_CODE,
                    "value_status":"OBSERVED", "confidence_score":0.90,
                    "source_detail":f"UNESCO UIS {uis_code} {year}"})
        except Exception as e:
            self.log.error("UNESCO %s erreur: %s", uis_code, e)
        return records

    def run(self, year_from=2000, year_to=2024, countries=None, dry_run=False):
        if countries is None:
            countries = list(AFRICAN_ISO3)
        ok=failed=inserted=rejected=0
        countries_seen=set()
        total=len(UNESCO_INDICATOR_MAP)
        for idx,(osa_code,cfg) in enumerate(UNESCO_INDICATOR_MAP.items(),1):
            self.log.info("[%d/%d] %s", idx, total, osa_code)
            try:
                records=self.fetch_indicator(osa_code,cfg,countries,year_from,year_to)
                countries_seen.update(r["country_iso3"] for r in records)
                nb_c=len(set(r["country_iso3"] for r in records))
                if dry_run:
                    self.log.info("[DRY-RUN] %-18s -> %d enregistrements (skippes)", osa_code, len(records))
                    ins,rej=len(records),0
                else:
                    ins,rej=self.insert_records(osa_code,records,cfg["multiplier"])
                inserted+=ins; rejected+=rej; ok+=1
                self.log.info("  %-18s -> %3d inseres, %2d rejetes, %2d pays", osa_code, ins, rej, nb_c)
            except Exception as e:
                self.log.error("Echec %s : %s", osa_code, e)
                failed+=1
        return {"provider":self.PROVIDER_CODE,"ok":ok,"failed":failed,
                "inserted":inserted,"rejected":rejected,"countries":len(countries_seen)}

    def probe(self):
        results=[]
        self.log.info("UNESCO -- sondage des bornes...")
        countries=list(AFRICAN_ISO3)
        for osa_code,cfg in UNESCO_INDICATOR_MAP.items():
            records=self.fetch_indicator(osa_code,cfg,countries,1970,2024)
            if records:
                years=sorted(set(r["year"] for r in records))
                nb_c=len(set(r["country_iso3"] for r in records))
                self.log.info("  %-18s %d -> %d (%d pays)", osa_code, years[0], years[-1], nb_c)
                results.append({"provider_code":self.PROVIDER_CODE,"indicator_code":osa_code,
                    "year_min":years[0],"year_max":years[-1],"countries_count":nb_c,"probe_status":"OK"})
            else:
                results.append({"provider_code":self.PROVIDER_CODE,"indicator_code":osa_code,
                    "year_min":None,"year_max":None,"countries_count":0,"probe_status":"UNAVAILABLE"})
        return results

    def disconnect(self):
        super().disconnect()
