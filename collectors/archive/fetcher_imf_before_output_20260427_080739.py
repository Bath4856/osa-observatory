"""
============================================================
OSA / ISA OBSERVATORY
fetcher_imf.py — Fetcher FMI (WEO + IFS)
============================================================
Couvre : 15 indicateurs pilier PMON (souveraineté monétaire)
API    : IMF DataMapper (WEO) + SDMX JSON (IFS)

Particularité IMF :
  - L'API DataMapper retourne TOUS les pays en une seule requête
  - Les codes pays IMF utilisent l'ISO-2
  - Certains indicateurs WEO ont une couverture africaine partielle
  - L'IFS (International Financial Statistics) complète le WEO
    pour les réserves et taux de change
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

import time

from fetcher_base import (
    AFRICAN_ISO3, ISO3_TO_ISO2, BaseFetcher, DataRecord,
    PAUSE_BETWEEN_CALLS,
)

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)


# ── Mapping indicateurs OSA → codes IMF ───────────────────

IMF_INDICATOR_MAP: dict = {

    # ── WEO (World Economic Outlook) ──────────────────────
    "MON_INF": {
        "source":     "WEO",
        "imf_code":   "PCPIPCH",
        "name_fr":    "Inflation (variation IPC %)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — variation annuelle IPC. Complète WB pour années récentes.",
    },
    "MON_EXT": {
        "source":     "WEO",
        "imf_code":   "GGXWDG_NGDP",
        "name_fr":    "Dette brute secteur public (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — dette brute administrations publiques / PIB",
    },
    "MON_PAY": {
        "source":     "WEO",
        "imf_code":   "BCA_NGDPD",
        "name_fr":    "Balance courante (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — balance des transactions courantes / PIB",
    },
    "ECO_GDP": {
        "source":     "WEO",
        "imf_code":   "NGDPD",
        "name_fr":    "PIB (milliards USD courants)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000_000.0,  # milliards → USD
        "notes":      "WEO — PIB nominal USD courants. Complément WB.",
    },
    "ECO_GRW": {
        "source":     "WEO",
        "imf_code":   "NGDP_RPCH",
        "name_fr":    "Croissance PIB réel (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — taux de croissance du PIB réel",
    },
    "MON_DET": {
        "source":     "WEO",
        "imf_code":   "GGXONLB_NGDP",
        "name_fr":    "Solde budgétaire (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — solde primaire excluant intérêts nets / PIB",
    },
    "ECO_UNE": {
        "source":     "WEO",
        "imf_code":   "LUR",
        "name_fr":    "Chômage (% population active)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — taux de chômage modélisé",
    },
    "MON_EXR": {
        "source":     "WEO",
        "imf_code":   "EREER",
        "name_fr":    "Taux de change effectif réel",
        "unit_code":  "INDEX",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — taux de change effectif réel (variation = volatilité)",
    },

    # ── IFS (International Financial Statistics) ──────────
    "MON_RES": {
        "source":     "IFS",
        "imf_code":   "RAFA_USD",
        "name_fr":    "Réserves officielles (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,  # millions → USD
        "notes":      "IFS — réserves de change officielles en millions USD",
    },
    "MON_M2": {
        "source":     "IFS",
        "imf_code":   "FMB_XDC",
        "name_fr":    "Monnaie au sens large M2 (monnaie locale)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "IFS — masse monétaire M2 en monnaie nationale. Proxy croissance financière.",
    },
    "MON_INT": {
        "source":     "IFS",
        "imf_code":   "FILR_PA",
        "name_fr":    "Taux de prêt (% annuel)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "IFS — taux d'intérêt de référence pour les prêts",
    },
    "MON_CUR": {
        "source":     "IFS",
        "imf_code":   "ENDA_XDC_USD_RATE",
        "name_fr":    "Taux de change (LCU/USD fin période)",
        "unit_code":  "RATIO",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "IFS — taux de change fin de période, monnaie locale/USD",
    },
    "MON_FIN": {
        "source":     "IFS",
        "imf_code":   "FOSA_XDC",
        "name_fr":    "Actifs secteur bancaire (monnaie locale)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "IFS — actifs totaux secteur bancaire. Proxy profondeur financière.",
    },
    # MON_STB retiré du fetcher IMF — remplacé par FB.BNK.CAPA.ZS (WB)
    # Le proxy LP (population totale) n'avait aucun lien avec la stabilité bancaire.
    "MON_AUT": {
        "source":     "WEO",
        "imf_code":   "GGX_NGDP",
        "name_fr":    "Dépenses publiques totales (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — proxy de capacité de l'État à conduire une politique budgétaire",
    },
}


# ── Fetcher IMF ────────────────────────────────────────────

class IMFFetcher(BaseFetcher):

    PROVIDER_CODE = "IMF"
    ENDPOINT_CODE = "IMF_WEO_INDICATOR"
    INDICATOR_MAP = IMF_INDICATOR_MAP

    # URL bases
    WEO_BASE = "https://www.imf.org/external/datamapper/api/v1"
    IFS_BASE = "https://dataservices.imf.org/REST/SDMX_JSON.svc"

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Dispatch vers WEO ou IFS selon la source configurée."""
        source = config.get("source", "WEO")
        if source == "WEO":
            return self._fetch_weo(osa_code, config, year_from, year_to)
        elif source == "IFS":
            return self._fetch_ifs(osa_code, config, year_from, year_to)
        else:
            self.log.error("Source inconnue '%s' pour %s", source, osa_code)
            return []

    # ── WEO ───────────────────────────────────────────────

    def _fetch_weo(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        API DataMapper WEO.
        Format : /api/v1/{indicateur}/{pays_iso2_liste}
        Retourne toutes les années disponibles — on filtre ensuite.
        """
        imf_code = config["imf_code"]

        # Decoupage en groupes de 20 pays — URL IMF limitee en longueur
        iso2_all = [ISO3_TO_ISO2[iso3] for iso3 in AFRICAN_ISO3 if iso3 in ISO3_TO_ISO2]
        groups = [iso2_all[i:i+20] for i in range(0, len(iso2_all), 20)]

        records: list[DataRecord] = []
        values_block: dict = {}

        for group in groups:
            iso2_list = "/".join(group)
            url = f"{self.WEO_BASE}/{imf_code}/{iso2_list}"
            data = self.http_get(url)
            if not data:
                continue
            values_block.update(data.get("values", {}).get(imf_code, {}))

        # Correspondance ISO-2 → ISO-3 (inverse)
        iso2_to_iso3 = {v: k for k, v in ISO3_TO_ISO2.items()}

        for iso2, year_data in values_block.items():
            iso3 = iso2_to_iso3.get(iso2.upper())
            if not iso3 or iso3 not in AFRICAN_ISO3:
                continue
            for year_str, value in year_data.items():
                if not year_str.isdigit():
                    continue
                year = int(year_str)
                if not (year_from <= year <= year_to):
                    continue
                try:
                    v = float(value) if value not in (None, "", "n/a", "--") else None
                except (ValueError, TypeError):
                    v = None
                records.append({"iso3": iso3, "year": year, "value": v})

        self.log.debug("WEO %s → %d enregistrements", imf_code, len(records))
        return records

    # ── IFS ───────────────────────────────────────────────

    def _fetch_ifs(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        API SDMX JSON (IFS).
        Format : /CompactData/IFS/A.{iso2}.{indicateur}?startPeriod=YYYY&endPeriod=YYYY
        On itère par pays (pas de batch natif sur IFS).
        """
        imf_code = config["imf_code"]
        records:  list[DataRecord] = []

        for iso3 in AFRICAN_ISO3:
            iso2 = ISO3_TO_ISO2.get(iso3)
            if not iso2:
                continue

            url = (
                f"{self.IFS_BASE}/CompactData/IFS"
                f"/A.{iso2}.{imf_code}"
                f"?startPeriod={year_from}&endPeriod={year_to}"
            )
            data = self.http_get(url)
            time.sleep(PAUSE_BETWEEN_CALLS * 2)  # 1s fixe entre pays — IFS est sensible au throttling
            if not data:
                continue

            try:
                series = (
                    data.get("CompactData", {})
                        .get("DataSet", {})
                        .get("Series")
                )
                if series is None:
                    continue
                # Series peut être un dict (1 série) ou une liste
                if isinstance(series, dict):
                    series = [series]

                for s in series:
                    obs_list = s.get("Obs", [])
                    if isinstance(obs_list, dict):
                        obs_list = [obs_list]
                    for obs in obs_list:
                        period = obs.get("@TIME_PERIOD", "")
                        value  = obs.get("@OBS_VALUE")
                        if not period.isdigit():
                            continue
                        try:
                            v = float(value) if value is not None else None
                        except (ValueError, TypeError):
                            v = None
                        records.append({"iso3": iso3, "year": int(period), "value": v})

            except (AttributeError, KeyError, TypeError) as exc:
                self.log.debug("Parsing IFS %s/%s : %s", iso3, imf_code, exc)
                continue

        self.log.debug("IFS %s → %d enregistrements", imf_code, len(records))
        return records


# ── CLI ────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="OSA Fetcher — IMF (WEO + IFS)")
    parser.add_argument("--year",      type=int)
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2022)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    args = parser.parse_args()

    year_from = year_to = args.year if args.year else args.year_from
    year_to   = args.year if args.year else args.year_to

    fetcher = IMFFetcher(dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(year_from, year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
