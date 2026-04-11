"""
============================================================
OSA / ISA OBSERVATORY
imf_csv_parser.py -- Parseur CSV commun aux datasets IMF
============================================================
Gere les 3 formats CSV IMF (nouveau format 2024+) :
  - WEO  (World Economic Outlook)        -- 26 Mo
  - DOTS (IMTS -- International Merchandise Trade Stats) -- 2.8 Go
  - BOP  (Balance of Payments)           -- 1.3 Go

Nouveau format unifie IMF (depuis ~2024) :
  SERIES_CODE = {ISO3}.{INDICATOR_CODE}.{PARTNER}.{FREQ}
    WEO  : DZA.PCPIPCH.A
    IMTS : DZA.XG_FOB_USD.FRA.A   (exports DZA vers France, annuel)
    BOP  : DZA.NETCD_T.CAB.USD.A  (balance courante DZA, annuel)

  FREQUENCY  = "Annual" | "Quarterly" | "Monthly"
  Colonnes annees : "2010", "2011"... (sans suffixe = annuel)

Notes IMTS (DOTS) :
  - Pas de code partenaire "World" -- somme de tous les partenaires individuels
  - Agregats regionaux exclus : TX126, TX598, TX799, TX884, TX898, TX899
  - ECO_COM (intra-africain) : somme sur partenaires africains uniquement
  - SCALE = "Millions" -- multiplier par 1_000_000 pour obtenir USD

Usage :
  from imf_csv_parser import IMFCSVParser
  records = IMFCSVParser.parse_weo("data/imf/WEO.csv", "PCPIPCH")
  records = IMFCSVParser.parse_dots("data/imf/DOTS.csv", "XG_FOB_USD")
  records = IMFCSVParser.parse_bop("data/imf/BOP.csv", "NETCD_T.CAB.USD")
============================================================
"""

from __future__ import annotations

import csv
import logging
from pathlib import Path
from typing import Optional

log = logging.getLogger("imf_csv_parser")

# ── Pays africains ISO-3 ──────────────────────────────────
AFRICAN_ISO3: set[str] = {
    "DZA","EGY","LBY","MAR","MRT","SDN","TUN",
    "BEN","BFA","CIV","CPV","GMB","GHA","GIN","GNB",
    "LBR","MLI","NER","NGA","SLE","SEN","TGO",
    "BDI","COM","DJI","ERI","ETH","KEN","MDG","MWI",
    "MUS","MOZ","RWA","SYC","SOM","SSD","TZA","UGA","ZMB","ZWE",
    "AGO","CMR","CAF","TCD","COG","COD","GNQ","GAB","STP",
    "BWA","SWZ","LSO","NAM","ZAF",
}

# ── Agregats regionaux IMTS a exclure de la sommation ─────
IMTS_REGIONAL_AGGREGATES: set[str] = {
    "TX126", "TX598", "TX799", "TX884", "TX898", "TX899",
    "W00", "WBG", "WSM",
}

# ── Mapping ISO-2 -> ISO-3 (fallback ancien format) ───────
ISO2_TO_ISO3: dict[str, str] = {
    "DZ":"DZA","EG":"EGY","LY":"LBY","MA":"MAR","MR":"MRT",
    "SD":"SDN","TN":"TUN","BJ":"BEN","BF":"BFA","CI":"CIV",
    "CV":"CPV","GM":"GMB","GH":"GHA","GN":"GIN","GW":"GNB",
    "LR":"LBR","ML":"MLI","NE":"NER","NG":"NGA","SL":"SLE",
    "SN":"SEN","TG":"TGO","BI":"BDI","KM":"COM","DJ":"DJI",
    "ER":"ERI","ET":"ETH","KE":"KEN","MG":"MDG","MW":"MWI",
    "MU":"MUS","MZ":"MOZ","RW":"RWA","SC":"SYC","SO":"SOM",
    "SS":"SSD","TZ":"TZA","UG":"UGA","ZM":"ZMB","ZW":"ZWE",
    "AO":"AGO","CM":"CMR","CF":"CAF","TD":"TCD","CG":"COG",
    "CD":"COD","GQ":"GNQ","GA":"GAB","ST":"STP","BW":"BWA",
    "SZ":"SWZ","LS":"LSO","NA":"NAM","ZA":"ZAF",
}

IMF_NUMERIC_TO_ISO3: dict[str, str] = {
    "612":"DZA","469":"EGY","672":"LBY","686":"MAR","682":"MRT",
    "732":"SDN","744":"TUN","638":"BEN","748":"BFA","662":"CIV",
    "624":"CPV","648":"GMB","652":"GHA","656":"GIN","654":"GNB",
    "668":"LBR","678":"MLI","692":"NER","694":"NGA","724":"SLE",
    "722":"SEN","742":"TGO","618":"BDI","632":"COM","611":"DJI",
    "643":"ERI","644":"ETH","664":"KEN","674":"MDG","676":"MWI",
    "684":"MUS","688":"MOZ","714":"RWA","718":"SYC","726":"SOM",
    "728":"SSD","738":"TZA","746":"UGA","754":"ZMB","698":"ZWE",
    "614":"AGO","622":"CMR","626":"CAF","628":"TCD","634":"COG",
    "636":"COD","642":"GNQ","646":"GAB","716":"STP","616":"BWA",
    "734":"SWZ","666":"LSO","728":"NAM","199":"ZAF",
}


def _parse_value(raw: str) -> Optional[float]:
    """Convertit une cellule CSV IMF en float."""
    if not raw:
        return None
    cleaned = raw.replace(",", "").replace(" ", "").strip()
    if cleaned.lower() in ("n/a", "na", "--", "...", "..", "", "nan"):
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


class IMFCSVParser:
    """Parseur statique pour les 3 formats CSV IMF (nouveau format 2024+)."""

    # ── WEO ──────────────────────────────────────────────────

    @staticmethod
    def parse_weo(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse WEO -- SERIES_CODE = ISO3.WEO_CODE.A
        Matching exact sur parts[1].

        Codes OSA utilises :
          PCPIPCH     MON_INF  Inflation IPC %
          GGXWDG_NGDP MON_EXT  Dette publique % PIB
          BCA_NGDPD   MON_PAY  Balance courante % PIB
          GGXONLB_NGDP MON_DET Solde budgetaire primaire % PIB
          GGX_NGDP    MON_AUT  Depenses publiques % PIB
          NGDPDPC     ECO_GDP  PIB/habitant USD
          NGDP_RPCH   ECO_GRW  Croissance PIB reel %
          LUR         ECO_UNE  Chomage %
          PCPIEPCH    ECO_INF  Inflation fin periode %
          LP          HUM_POP  Population totale (millions)
        """
        records: list[dict] = []
        filepath = Path(filepath)
        if not filepath.exists():
            log.error("WEO introuvable : %s", filepath)
            return []

        imf_upper = imf_code.upper()
        year_cols = {y: str(y) for y in range(year_from, year_to + 1)}

        try:
            with open(filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(4096); f.seek(0)
                delim  = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delim)

                for row in reader:
                    freq = row.get("FREQUENCY", "").strip().lower()
                    if freq and freq not in ("annual", "a", "yearly"):
                        continue

                    sc = row.get("SERIES_CODE", "").strip()
                    if sc:
                        parts = sc.split(".")
                        iso3  = parts[0].upper()
                        code  = parts[1].upper() if len(parts) >= 2 else ""
                    else:
                        iso3 = IMFCSVParser._fallback_iso3(row)
                        code = IMFCSVParser._fallback_indicator(row)

                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue
                    if code != imf_upper:
                        continue

                    for year, col in year_cols.items():
                        records.append({
                            "iso3":  iso3,
                            "year":  year,
                            "value": _parse_value(row.get(col, "")),
                        })

        except Exception as exc:
            log.error("Erreur WEO %s : %s", filepath.name, exc)

        log.info("WEO %s -> %d enregistrements (%d pays)",
                 imf_code, len(records),
                 len({r["iso3"] for r in records if r["value"] is not None}))
        return records

    # ── DOTS (IMTS) ───────────────────────────────────────────

    @staticmethod
    def parse_dots(
        filepath:    str | Path,
        imf_code:    str,
        year_from:   int = 2010,
        year_to:     int = 2024,
        africa_only: bool = False,
    ) -> list[dict]:
        """
        Parse IMTS (International Merchandise Trade Statistics).
        Fichier telecharge depuis data.imf.org (IMTS dataset).

        Format SERIES_CODE = ISO3.INDICATOR.PARTNER.FREQ
          ex: DZA.XG_FOB_USD.FRA.A  (exports DZA -> France, annuel)

        Agregation :
          - Pas de code World total -- on somme tous les partenaires individuels
          - Exclusion automatique des agregats regionaux TX...
          - africa_only=True : ne sommer que les partenaires africains
            (utilise pour ECO_COM -- commerce intra-africain)
          - SCALE = Millions -- le fetcher applique multiplier=1_000_000

        Codes OSA utilises :
          XG_FOB_USD  ECO_EXP  Exportations biens FOB (millions USD)
          MG_CIF_USD  ECO_IMP  Importations biens CIF (millions USD)
          TBG_USD     ECO_DIV  Balance commerciale (millions USD)
          XG_FOB_USD  ECO_COM  Exports intra-africains (africa_only=True)
        """
        filepath = Path(filepath)
        if not filepath.exists():
            log.error("DOTS introuvable : %s", filepath)
            return []

        imf_upper = imf_code.upper()
        year_cols = {y: str(y) for y in range(year_from, year_to + 1)}

        # Accumulateurs par (iso3, year)
        totals: dict[tuple, float] = {}
        seen:   set[tuple]         = set()

        try:
            with open(filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(4096); f.seek(0)
                delim  = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delim)

                for row in reader:
                    freq = row.get("FREQUENCY", "").strip().lower()
                    if freq not in ("annual", "a", "yearly"):
                        continue

                    sc = row.get("SERIES_CODE", "").strip()
                    if not sc:
                        continue

                    parts = sc.split(".")
                    # Format minimum : ISO3.INDICATOR.PARTNER.FREQ (4 parties)
                    if len(parts) < 4:
                        continue

                    iso3      = parts[0].upper()
                    indicator = parts[1].upper()
                    partner   = parts[2].upper()

                    if iso3 not in AFRICAN_ISO3:
                        continue
                    if indicator != imf_upper:
                        continue
                    if partner in IMTS_REGIONAL_AGGREGATES:
                        continue
                    if africa_only and partner not in AFRICAN_ISO3:
                        continue

                    # Sommer par annee
                    for year, col in year_cols.items():
                        key   = (iso3, year)
                        value = _parse_value(row.get(col, ""))
                        seen.add(key)
                        if value is not None:
                            totals[key] = totals.get(key, 0.0) + value

        except Exception as exc:
            log.error("Erreur DOTS %s : %s", filepath.name, exc)

        # Construire records finaux
        records = [
            {"iso3": iso3, "year": year, "value": totals.get((iso3, year))}
            for iso3, year in seen
        ]

        suffix = " (intra-africain)" if africa_only else ""
        log.info("DOTS %s%s -> %d enregistrements (%d pays)",
                 imf_code, suffix, len(records),
                 len({r["iso3"] for r in records if r["value"] is not None}))
        return records

    # ── BOP ──────────────────────────────────────────────────

    @staticmethod
    def parse_bop(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse BOP -- SERIES_CODE = ISO3.BOP_CODE.UNIT.FREQ
        Matching par prefixe (le code peut contenir des points).

        Codes OSA utilises :
          NETCD_T.CAB.USD   MON_PAY  Balance courante (millions USD)
          NETCD_T.IN1.USD   MON_DEP  Revenus primaires nets (millions USD)
          A_NFA_T.D_F.USD   ECO_FDI  Investissement direct total (millions USD)
        """
        filepath = Path(filepath)
        if not filepath.exists():
            log.error("BOP introuvable : %s", filepath)
            return []

        imf_upper = imf_code.upper()
        year_cols = {y: str(y) for y in range(year_from, year_to + 1)}
        records: list[dict] = []

        try:
            with open(filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(4096); f.seek(0)
                delim  = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delim)

                for row in reader:
                    freq = row.get("FREQUENCY", "").strip().lower()
                    if freq not in ("annual", "a", "yearly"):
                        continue

                    sc = row.get("SERIES_CODE", "").strip()
                    if not sc:
                        continue

                    parts = sc.split(".")
                    if len(parts) < 3:
                        continue

                    iso3 = parts[0].upper()
                    if iso3 not in AFRICAN_ISO3:
                        continue

                    # Code BOP = tout entre ISO3 et la frequence finale
                    # ex: DZA.NETCD_T.CAB.USD.A -> code = NETCD_T.CAB.USD
                    code = ".".join(parts[1:-1]).upper()

                    if code != imf_upper and not code.startswith(imf_upper + "."):
                        continue

                    for year, col in year_cols.items():
                        records.append({
                            "iso3":  iso3,
                            "year":  year,
                            "value": _parse_value(row.get(col, "")),
                        })

        except Exception as exc:
            log.error("Erreur BOP %s : %s", filepath.name, exc)

        log.info("BOP %s -> %d enregistrements (%d pays)",
                 imf_code, len(records),
                 len({r["iso3"] for r in records if r["value"] is not None}))
        return records

    # ── Utilitaires ───────────────────────────────────────────

    @staticmethod
    def _fallback_iso3(row: dict) -> Optional[str]:
        iso2 = (
            row.get("ISO", "") or row.get("ISO2", "") or row.get("Country Code", "")
        ).strip().upper()
        iso3 = ISO2_TO_ISO3.get(iso2)
        if not iso3:
            weo_num = row.get("WEO Country Code", "").strip()
            iso3 = IMF_NUMERIC_TO_ISO3.get(weo_num)
        return iso3

    @staticmethod
    def _fallback_indicator(row: dict) -> str:
        return (
            row.get("WEO Subject Code", "") or
            row.get("Subject Code", "") or
            row.get("Indicator Code", "") or
            row.get("CONCEPT", "")
        ).strip().upper()

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 3) -> None:
        """Affiche la structure d'un fichier CSV IMF."""
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample = f.read(4096); f.seek(0)
            delim  = "\t" if "\t" in sample else ","
            reader = csv.DictReader(f, delimiter=delim)
            fields = reader.fieldnames or []
            year_cols = [c for c in fields if c.isdigit() and 1948 <= int(c) <= 2030]
            meta_cols = [c for c in fields if c not in year_cols
                         and not (len(c) > 4 and c[:4].isdigit())]
            print(f"\nColonnes de {filepath.name} :")
            print("  " + ", ".join(meta_cols))
            if year_cols:
                print(f"  Annees : {year_cols[0]} -> {year_cols[-1]} ({len(year_cols)})")
            print(f"\nPremieres {max_rows} lignes :")
            for i, row in enumerate(reader):
                if i >= max_rows: break
                print(f"  {dict(list(row.items())[:8])}")

    @staticmethod
    def scan_codes(
        filepath:  str | Path,
        iso3:      str = "DZA",
        max_codes: int = 30,
    ) -> None:
        """Liste les codes indicateurs disponibles pour un pays."""
        filepath   = Path(filepath)
        iso3_upper = iso3.upper()
        codes: set[str] = set()
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample = f.read(4096); f.seek(0)
            delim  = "\t" if "\t" in sample else ","
            for row in csv.DictReader(f, delimiter=delim):
                sc   = row.get("SERIES_CODE", "").strip()
                freq = row.get("FREQUENCY", "").strip().lower()
                if not sc or freq not in ("annual", "a", "yearly", ""):
                    continue
                parts = sc.split(".")
                if parts[0].upper() != iso3_upper:
                    continue
                codes.add(parts[1].upper() if len(parts) >= 2 else "")
                if len(codes) >= max_codes:
                    break
        print(f"\nCodes disponibles pour {iso3} ({filepath.name}) :")
        for c in sorted(codes)[:max_codes]:
            print(f"  {c}")