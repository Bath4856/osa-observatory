"""OSA fetcher_undp — UNDP HDR CSV direct"""
from __future__ import annotations
import csv, io
from fetcher_base import AFRICAN_ISO3, SAMPLE_ISO3, BaseFetcher, DataRecord

UNDP_CSV_URL = "https://hdr.undp.org/sites/default/files/2023-24_HDR/HDR23-24_Composite_indices_complete_time_series.csv"

UNDP_INDICATOR_MAP = {
    "HUM_EDU": {"col_prefix":"eys","name_fr":"Annees scolarisation attendues","unit_code":"YEARS","direction":"+","multiplier":1.0,"notes":"UNDP HDR EYS 1990-2022"},
    "HUM_GEN": {"col_prefix":"gii","name_fr":"Indice inegalite genre GII","unit_code":"INDEX_0_1","direction":"-","multiplier":1.0,"notes":"UNDP HDR GII 1990-2022"},
    "HUM_LIT": {"col_prefix":"mys","name_fr":"Annees moyennes scolarisation","unit_code":"YEARS","direction":"+","multiplier":1.0,"notes":"UNDP HDR MYS 1990-2022"},
}

class UNDPFetcher(BaseFetcher):
    PROVIDER_CODE  = "UNDP"
    ENDPOINT_CODE  = "UNDP_HDI"
    SOURCE_CODE    = "UNDP"
    def connect(self):
        self.log.info("UNDP -- telechargement CSV HDR...")
        import requests
        r = requests.get(UNDP_CSV_URL, timeout=30)
        if r.status_code != 200:
            raise ConnectionError(f"UNDP CSV HTTP {r.status_code}")
        content = r.content.decode("latin-1")
        self._rows = {}
        for row in csv.DictReader(io.StringIO(content)):
            iso3 = row.get("iso3","").strip().upper()
            if iso3:
                self._rows[iso3] = row
        self.log.info("UNDP -- %d pays charges", len(self._rows))
        super().connect()
    def fetch_indicator(self, osa_code, cfg, countries, year_from, year_to):
        records = []
        for iso3 in countries:
            row = self._rows.get(iso3)
            if not row:
                continue
            for year in range(year_from, year_to + 1):
                col = f"{cfg['col_prefix']}_{year}"
                raw = row.get(col,"").strip()
                if not raw:
                    continue
                try:
                    value = float(raw) * cfg["multiplier"]
                except ValueError:
                    continue
                records.append({"country_iso3": iso3, "indicator_code": osa_code, "year": year, "value": value, "unit_code": cfg["unit_code"], "provider_code": self.PROVIDER_CODE, "value_status": "OBSERVED", "confidence_score": 0.95, "source_detail": f"UNDP HDR 2023-24 {col}"})
        return records
    def run(self, year_from=1990, year_to=2022, countries=None, dry_run=False):
        if countries is None:
            countries = list(AFRICAN_ISO3)
        ok=failed=inserted=rejected=0
        countries_seen=set()
        total=len(UNDP_INDICATOR_MAP)
        for idx,(osa_code,cfg) in enumerate(UNDP_INDICATOR_MAP.items(),1):
            self.log.info("[%d/%d] %s", idx, total, osa_code)
            try:
                records=self.fetch_indicator(osa_code,cfg,countries,year_from,year_to)
                countries_seen.update(r["country_iso3"] for r in records)
                nb_c=len(set(r["country_iso3"] for r in records))
                if dry_run:
                    self.log.info("[DRY-RUN] %-18s -> %d enregistrements (skippes)", osa_code, len(records))
                    ins,rej=len(records),0
                else:
                    ins,rej=self.insert_records(osa_code, records, cfg["multiplier"])
                inserted+=ins; rejected+=rej; ok+=1
                self.log.info("  %-18s -> %3d inseres, %2d rejetes, %2d pays", osa_code, ins, rej, nb_c)
            except Exception as exc:
                self.log.error("Echec %s : %s", osa_code, exc)
                failed+=1
        return {"provider":self.PROVIDER_CODE,"ok":ok,"failed":failed,"inserted":inserted,"rejected":rejected,"countries":len(countries_seen)}
    def probe(self):
        results=[]
        self.log.info("UNDP -- sondage des bornes...")
        countries = list(AFRICAN_ISO3)
        for osa_code,cfg in UNDP_INDICATOR_MAP.items():
            years_data=[]
            for year in range(1990,2023):
                col=f"{cfg['col_prefix']}_{year}"
                count=sum(1 for iso3 in countries if iso3 in self._rows and self._rows[iso3].get(col,"").strip())
                if count>0:
                    years_data.append((year,count))
            if years_data:
                y_min,y_max=years_data[0][0],years_data[-1][0]
                avg_c=sum(c for _,c in years_data)//len(years_data)
                self.log.info("  %-18s %d -> %d (%d pays)", osa_code, y_min, y_max, avg_c)
                results.append({"provider_code":self.PROVIDER_CODE,"indicator_code":osa_code,"year_min":y_min,"year_max":y_max,"countries_count":avg_c,"probe_status":"OK"})
            else:
                results.append({"provider_code":self.PROVIDER_CODE,"indicator_code":osa_code,"year_min":None,"year_max":None,"countries_count":0,"probe_status":"UNAVAILABLE"})
        return results
    def disconnect(self):
        self._rows={}
        super().disconnect()
