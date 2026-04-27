"""
============================================================
OSA / ISA OBSERVATORY
fetcher_who.py — Fetcher OMS (WHO GHO API)
============================================================
Couvre : 10 indicateurs pilier PHUM (souveraineté humaine)
API    : WHO Global Health Observatory (GHO) — OData REST

Particularités WHO GHO :
  - L'API utilise OData 4.0 avec $filter, $select
  - Les codes pays sont en ISO-2 dans GHO (SpatialDim)
  - Certains indicateurs ont des dimensions supplémentaires
    (SEX : MLE/FMLE/BTSX) — on prend BTSX (les deux sexes)
  - La fréquence est annuelle mais avec des lacunes fréquentes
  - L'API peut être lente sur les grands pays — pagination nécessaire
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

import fetcher_base as _fb
from fetcher_base import ISO3_TO_ISO2, BaseFetcher, DataRecord

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Mapping indicateurs OSA → codes GHO ───────────────────

WHO_INDICATOR_MAP: dict = {

    "HUM_HEA": {
        "gho_code":   "WHOSIS_000001",
        "name_fr":    "Espérance de vie à la naissance (total)",
        "unit_code":  "YEARS",
        "direction":  "+",
        "multiplier": 1.0,
        "sex_filter": None,  # filtre cote Python apres reception   # Both sexes
        "notes":      "GHO — espérance de vie totale. Très bonne couverture africaine.",
    },
    "HUM_INF": {
        "gho_code":   "MDG_0000000007",
        "name_fr":    "Mortalité infantile < 5 ans (pour 1000)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 0.1,      # pour 1000 → %
        "sex_filter": "SEX_BTSX",
        "notes":      "GHO — taux mortalité moins de 5 ans pour 1000 naissances vivantes",
    },
    "HUM_HEA2": {
        "gho_code":   "UHC_INDEX_REPORTED",
        "name_fr":    "Indice accès et qualité des soins (HAQ)",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 1.0,
        "sex_filter": None,
        "notes":      "GHO — Healthcare Access and Quality Index (0-100)",
    },
    "HUM_WAT": {
        "gho_code":   "WSH_WATER_SAFELY_MANAGED",
        "name_fr":    "Accès eau gérée sans risque (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "sex_filter": None,
        "notes":      "GHO — population avec accès eau gérée sans risque (SDG 6.1)",
    },
    "HUM_SAN": {
        "gho_code":   "WSH_SANITATION_SAFELY_MANAGED",
        "name_fr":    "Accès assainissement géré sans risque (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "sex_filter": None,
        "notes":      "GHO — SDG 6.2 — assainissement sécurisé",
    },
    "HUM_POV": {
        "gho_code":   "NCD_BMI_30C",
        "name_fr":    "Prévalence obésité adultes (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "sex_filter": "SEX_BTSX",
        "notes":      "GHO — proxy de transition nutritionnelle. HUM_POV complété par WB.",
    },
    "HUM_FOO": {
        "gho_code":   "NUTRITION_ANAEMIA_PREGNANT_PREV",
        "name_fr":    "Prévalence anémie femmes enceintes (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "sex_filter": None,
        "notes":      "GHO — proxy de sécurité nutritionnelle. Complète FAO pour HUM_FOO.",
    },
    "HUM_GEN": {
        "gho_code":   "MDG_0000000026",
        "name_fr":    "Ratio mortalité maternelle (pour 100 000)",
        "unit_code":  "RATIO",
        "direction":  "-",
        "multiplier": 1.0,
        "sex_filter": None,
        "notes":      "GHO — mortalité maternelle, indicateur clé égalité genre/santé",
    },
    # HUM_EDU retiré du fetcher WHO — remplacé par SE.SEC.ENRR (WB)
    # Le proxy HWF_0001 (densité médecins) mesure la santé, pas l'éducation.
    # HUM_MIG retiré du fetcher WHO — remplacé par SM.POP.NETM (WB)
    # Le proxy NCDMORT3070 (mortalité MNT) n'a aucun lien avec la fuite des cerveaux.
}


# ── Fetcher WHO ────────────────────────────────────────────

class WHOFetcher(BaseFetcher):

    PROVIDER_CODE = "WHO"
    ENDPOINT_CODE = "WHO_GHO_INDICATOR"
    INDICATOR_MAP = WHO_INDICATOR_MAP

    GHO_BASE = "https://ghoapi.azureedge.net/api"
    GHO_PAGE_SIZE = 1000

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Appelle l'API GHO pour un indicateur.
        Filtre sur les pays africains ISO-2 et la plage d'années.
        """
        gho_code   = config["gho_code"]
        sex_filter = config.get("sex_filter")

        # Filtre OData — années et sexe seulement.
        # Le filtre pays (54 codes iso2 en clause 'or') rendait l'URL trop longue
        # (~2000 chars encodés, limite Azure CDN ≈ 2048). On filtre les pays
        # côté Python après réception — le volume max est ~3 pages de 1000 lignes.
        # Filtre OData — sexe uniquement.
        # TimeDim ne supporte pas les filtres numeriques dans GHO API.
        # Le filtrage des annees se fait cote Python apres reception.
        odata_filter = None
        if sex_filter:
            odata_filter = f"Dim1 eq '{sex_filter}'"

        # GHO utilise ISO-3 directement dans SpatialDim
        african_iso3 = set(_fb.AFRICAN_ISO3)

        url    = f"{self.GHO_BASE}/{gho_code}"
        params = {
            **( {"$filter": odata_filter} if odata_filter else {} ),
            "$select": "SpatialDim,TimeDim,NumericValue",
            "$top":    self.GHO_PAGE_SIZE,
        }

        records: list[DataRecord] = []

        def process_row(row):
            iso3 = (row.get("SpatialDim") or "").upper()
            if iso3 not in african_iso3:
                return
            time_dim = row.get("TimeDim")
            value    = row.get("NumericValue")
            if time_dim is None:
                return
            if not (year_from <= int(time_dim) <= year_to):
                return
            try:
                v = float(value) if value is not None else None
            except (ValueError, TypeError):
                v = None
            records.append({"iso3": iso3, "year": int(time_dim), "value": v})

        if odata_filter is None:
            # Pas de filtre sexe — requete par pays pour eviter pagination globale
            for iso3 in african_iso3:
                country_params = dict(params)
                country_params["$filter"] = f"SpatialDim eq '{iso3}'"
                data = self.http_get(url, params=country_params)
                if not data:
                    continue
                for row in data.get("value", []):
                    process_row(row)
        else:
            # Filtre sexe — pagination globale
            skip = 0
            while True:
                params["$skip"] = skip
                data = self.http_get(url, params=params)
                if not data:
                    break
                page = data.get("value", [])
                if not page:
                    break
                for row in page:
                    process_row(row)
                if len(page) < self.GHO_PAGE_SIZE:
                    break
                skip += self.GHO_PAGE_SIZE

        self.log.debug("GHO %s → %d enregistrements", gho_code, len(records))
        return records


# ── CLI ────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="OSA Fetcher — WHO GHO")
    parser.add_argument("--year",      type=int)
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2022)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    args = parser.parse_args()

    year_from = year_to = args.year if args.year else args.year_from
    year_to   = args.year if args.year else args.year_to

    fetcher = WHOFetcher(dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(year_from, year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
