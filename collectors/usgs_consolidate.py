"""
============================================================
OSA / ISA OBSERVATORY
usgs_consolidate.py — Consolidation CSV USGS brut → format OSA
============================================================
Transforme MCS_2024.csv (format brut USGS, une ligne par minerai/pays)
en MCS_2024_consolidated.csv (format normalisé OSA, une ligne par pays/année)

Format brut USGS (entrée) :
  SOURCE | COMMODITY | COUNTRY | TYPE | UNIT_MEAS |
  PROD_2023 | PROD_EST_ 2024 | RESERVES_2024 | ...

Format OSA normalisé (sortie) :
  country | year | reserves_mt | production_mt |
  exports_usd | commodity_count

Stratégie MIN_RES (valeur USD) :
  Conversion tonnes → USD via prix de référence USGS MCS 2024.
  Les prix sont les prix moyens annuels publiés dans le rapport MCS 2025
  (Table 1 — Salient Statistics for nonfuel minerals).
  Unités hétérogènes normalisées en tonnes métriques avant conversion.

Usage :
  python usgs_consolidate.py --dir data/usgs/
  python usgs_consolidate.py --dir data/usgs/ --dry-run
  python usgs_consolidate.py --dir data/usgs/ --verbose
============================================================
"""

from __future__ import annotations

import argparse
import csv
import logging
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("usgs_consolidate")

# ── Mapping noms USGS → ISO-3 (même dict que fetcher) ─────
USGS_COUNTRY_TO_ISO3: dict[str, str] = {
    "Algeria": "DZA", "Egypt": "EGY", "Libya": "LBY", "Morocco": "MAR",
    "Mauritania": "MRT", "Sudan": "SDN", "Tunisia": "TUN",
    "Benin": "BEN", "Burkina Faso": "BFA", "Côte d'Ivoire": "CIV",
    "Cote d'Ivoire": "CIV", "Ivory Coast": "CIV", "Cape Verde": "CPV",
    "Cabo Verde": "CPV", "Gambia": "GMB", "Ghana": "GHA", "Guinea": "GIN",
    "Guinea-Bissau": "GNB", "Liberia": "LBR", "Mali": "MLI", "Niger": "NER",
    "Nigeria": "NGA", "Sierra Leone": "SLE", "Senegal": "SEN", "Togo": "TGO",
    "Burundi": "BDI", "Comoros": "COM", "Djibouti": "DJI", "Eritrea": "ERI",
    "Ethiopia": "ETH", "Kenya": "KEN", "Madagascar": "MDG", "Malawi": "MWI",
    "Mauritius": "MUS", "Mozambique": "MOZ", "Rwanda": "RWA",
    "Seychelles": "SYC", "Somalia": "SOM", "South Sudan": "SSD",
    "Tanzania": "TZA", "Uganda": "UGA", "Zambia": "ZMB", "Zimbabwe": "ZWE",
    "Angola": "AGO", "Cameroon": "CMR", "Central African Republic": "CAF",
    "Chad": "TCD", "Congo, Republic of the": "COG", "Congo (Brazzaville)": "COG",
    "Congo": "COG", "Congo, Democratic Republic": "COD",
    "Congo (Kinshasa)": "COD", "DRC": "COD", "Zaire": "COD",
    "Equatorial Guinea": "GNQ", "Gabon": "GAB", "Sao Tome and Principe": "STP",
    "Botswana": "BWA", "Eswatini": "SWZ", "Swaziland": "SWZ",
    "Lesotho": "LSO", "Namibia": "NAM", "South Africa": "ZAF",
}

# ── Prix de référence USGS MCS 2025 (USD / tonne métrique) ─
# Source : USGS Mineral Commodity Summaries 2025, Table 1
# Salient Statistics — prix moyens 2023-2024
# Pour les minerais sans prix direct, valeur proxy conservatrice.
USD_PER_TONNE: dict[str, float] = {
    # Métaux précieux
    "Gold":              62_000_000.0,   # ~62 000 USD/kg → 62 Md USD/t
    "Silver":               830_000.0,   # ~830 USD/kg
    "Platinum":          30_000_000.0,
    "Palladium":         40_000_000.0,
    # Pierres précieuses (proxy valeur de réserve en USD/tonne)
    "Diamond (industrial)":  2_000_000.0,  # par tonne métrique brut
    "Gemstones":               500_000.0,
    # Métaux de base
    "Copper":                8_500.0,
    "Cobalt":               33_000.0,
    "Nickel":               16_000.0,
    "Zinc":                  2_500.0,
    "Lead":                  2_100.0,
    "Tin":                  26_000.0,
    "Aluminum":              2_300.0,
    "Bauxite":                  45.0,   # minerai brut
    # Métaux de spécialité
    "Chromium":              1_200.0,
    "Manganese":             2_000.0,
    "Lithium":              22_000.0,
    "Titanium":              4_500.0,
    "Vanadium":             30_000.0,
    "Tungsten":             35_000.0,
    "Molybdenum":           40_000.0,
    "Tantalum":            130_000.0,
    "Niobium":              41_000.0,
    # Minéraux industriels
    "Phosphate rock":           120.0,
    "Potash":                   320.0,
    "Fluorspar":                390.0,
    "Graphite":               1_000.0,
    "Iron Ore":                 120.0,
    "Coal":                     140.0,
    "Uranium":              130_000.0,
    "Garnet (industrial)":      300.0,
    "Clays":                     50.0,
    "Barite":                   120.0,
    "Gypsum":                    15.0,
    "Silica":                    30.0,
    "Salt":                      80.0,
    "Arsenic":                1_500.0,
    "Bismuth":                6_000.0,
    "Cadmium":                2_500.0,
}

# Fallback prix pour minerais non listés (proxy conservateur)
DEFAULT_USD_PER_TONNE = 500.0

# ── Facteurs de conversion → tonnes métriques ─────────────
UNIT_TO_TONNES: dict[str, float] = {
    "metric tons":              1.0,
    "metric ton":               1.0,
    "thousand metric tons":     1_000.0,
    "thousand metric dry tons": 1_000.0,
    "million metric tons":      1_000_000.0,
    "kilograms":                0.001,
    "thousand carats":          0.2,        # 1 carat = 0.0002 kg → 1000 carats = 0.2 kg ≈ 0.0002 t
    "million carats":           200.0,      # 1M carats = 200 kg = 0.2 t → 200 t
    "million cubic meters":     0.0,        # non convertible (gaz) → exclure
}


def parse_usgs_value(raw: str) -> Optional[float]:
    """Convertit une cellule USGS en float. Gère W, XX, e, r, --, virgules."""
    if not raw:
        return None
    cleaned = raw.replace(",", "").replace(" ", "")
    cleaned = cleaned.rstrip("eErRpPwW")
    cleaned = cleaned.strip("()")
    if cleaned.lower() in ("w", "xx", "--", "na", "n/a", "...", ""):
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def normalize_commodity(raw: str) -> str:
    """Normalise le nom du minerai pour lookup dans USD_PER_TONNE."""
    return raw.strip().title()


def to_tonnes(value: float, unit_raw: str) -> Optional[float]:
    """Convertit une valeur dans son unité d'origine en tonnes métriques."""
    unit = unit_raw.strip().lower()
    for key, factor in UNIT_TO_TONNES.items():
        if unit == key.lower():
            if factor == 0.0:
                return None  # non convertible
            return value * factor
    # Unité inconnue — tenter une correspondance partielle
    if "million metric" in unit:
        return value * 1_000_000.0
    if "thousand metric" in unit or "thousand dry" in unit:
        return value * 1_000.0
    if "kilogram" in unit:
        return value * 0.001
    if "carat" in unit:
        if "million" in unit:
            return value * 200.0
        if "thousand" in unit:
            return value * 0.2
    log.debug("Unité inconnue ignorée : '%s'", unit_raw)
    return None


def commodity_to_usd_per_tonne(commodity: str) -> float:
    """Retourne le prix USD/tonne pour un minerai donné."""
    normalized = normalize_commodity(commodity)
    # Recherche exacte
    if normalized in USD_PER_TONNE:
        return USD_PER_TONNE[normalized]
    # Recherche partielle
    for key, price in USD_PER_TONNE.items():
        if key.lower() in normalized.lower() or normalized.lower() in key.lower():
            return price
    return DEFAULT_USD_PER_TONNE


def consolidate_mcs(
    csv_path: Path,
    year: int,
    verbose: bool = False,
) -> dict[str, dict]:
    """
    Consolide MCS_2024.csv brut en agrégats par pays pour une année donnée.

    Retourne un dict : iso3 → {
        reserves_usd: float,
        production_usd: float,
        commodity_count: int,
        commodities: list[str],
    }
    """
    # MCS couvre une seule année (année de publication - 1)
    # PROD_2023 = production 2023, RESERVES_2024 = réserves fin 2024
    prod_col     = f"PROD_{year}"
    prod_est_col = f"PROD_EST_ {year + 1}"   # colonne avec espace USGS
    res_col      = f"RESERVES_{year + 1}"    # réserves publiées l'année suivante

    country_data: dict[str, dict] = defaultdict(lambda: {
        "reserves_usd":    0.0,
        "production_usd":  0.0,
        "commodity_count": 0,
        "commodities":     [],
    })

    skipped_country  = 0
    skipped_unit     = 0
    skipped_novalue  = 0
    processed        = 0

    with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
        reader = csv.DictReader(f)
        fieldnames = [c.strip() for c in (reader.fieldnames or [])]

        # Adapter les noms de colonnes réels (USGS a des espaces parasites)
        raw_fields = reader.fieldnames or []

        for row in reader:
            # Normaliser les clés
            row = {k.strip(): v.strip() for k, v in row.items()}

            country_raw = row.get("COUNTRY", "").strip()
            iso3 = USGS_COUNTRY_TO_ISO3.get(country_raw)
            if not iso3:
                skipped_country += 1
                continue

            commodity = row.get("COMMODITY", "").strip()
            unit_raw  = row.get("UNIT_MEAS", "").strip()

            # Ignorer les lignes de capacité (pas production ni réserves)
            type_raw = row.get("TYPE", "").lower()
            if "capacity" in type_raw:
                continue

            # ── Réserves ──────────────────────────────────────
            res_raw = row.get(res_col, "").strip()
            if not res_raw:
                # Essayer colonne alternative
                for k in row:
                    if "RESERVE" in k.upper() and k != "RESERVE_NOTES":
                        res_raw = row[k].strip()
                        break

            res_val = parse_usgs_value(res_raw)

            # ── Production ────────────────────────────────────
            prod_raw = row.get(prod_col, row.get(prod_est_col, "")).strip()
            prod_val = parse_usgs_value(prod_raw)

            if res_val is None and prod_val is None:
                skipped_novalue += 1
                continue

            # ── Conversion en tonnes puis USD ─────────────────
            usd_per_t = commodity_to_usd_per_tonne(commodity)

            if res_val is not None:
                res_tonnes = to_tonnes(res_val, unit_raw)
                if res_tonnes is not None:
                    country_data[iso3]["reserves_usd"] += res_tonnes * usd_per_t
                    country_data[iso3]["commodity_count"] += 1
                    country_data[iso3]["commodities"].append(commodity)
                    processed += 1
                else:
                    skipped_unit += 1

            if prod_val is not None:
                prod_tonnes = to_tonnes(prod_val, unit_raw)
                if prod_tonnes is not None:
                    country_data[iso3]["production_usd"] += prod_tonnes * usd_per_t

            if verbose:
                log.debug(
                    "%-25s | %-25s | res=%-12s | prod=%-12s | unit=%s",
                    country_raw, commodity, res_raw, prod_raw, unit_raw,
                )

    log.info(
        "MCS parsing — traités:%d | pays ignorés:%d | unités inconnues:%d | sans valeur:%d",
        processed, skipped_country, skipped_unit, skipped_novalue,
    )
    return dict(country_data)


def write_consolidated(
    data: dict[str, dict],
    output_path: Path,
    year: int,
) -> None:
    """Écrit le CSV normalisé attendu par _parse_mcs."""
    fieldnames = [
        "country", "year", "reserves_mt", "production_mt",
        "exports_usd", "commodity_count", "reserves_usd", "production_usd",
        "commodities",
    ]
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for iso3, d in sorted(data.items()):
            writer.writerow({
                "country":        iso3,
                "year":           year,
                # reserves_mt : valeur brute non normalisable (unités mixtes)
                # → on expose reserves_usd comme proxy MIN_RES
                "reserves_mt":    round(d["reserves_usd"] / 1_000_000, 6),
                "production_mt":  round(d["production_usd"] / 1_000_000, 6),
                "exports_usd":    "",   # non disponible dans MCS
                "commodity_count": d["commodity_count"],
                "reserves_usd":   round(d["reserves_usd"] / 1_000_000, 6),
                "production_usd": round(d["production_usd"] / 1_000_000, 6),
                "commodities":    "|".join(d["commodities"]),
            })
    log.info("Fichier consolidé écrit : %s (%d pays)", output_path.name, len(data))


def print_summary(data: dict[str, dict], year: int) -> None:
    """Affiche un résumé par pays trié par valeur des réserves."""
    print(f"\n{'─'*72}")
    print(f"  Résumé consolidation MCS {year} — {len(data)} pays africains")
    print(f"{'─'*72}")
    print(f"  {'ISO3':6} {'Réserves (Md USD)':>18} {'Minerais':>8}  Principaux")
    print(f"{'─'*72}")
    for iso3, d in sorted(data.items(), key=lambda x: x[1]["reserves_usd"], reverse=True):
        res_bn  = d["reserves_usd"] / 1e9
        top3    = ", ".join(d["commodities"][:3])
        suffix  = "..." if len(d["commodities"]) > 3 else ""
        print(f"  {iso3:6} {res_bn:>18.1f} {d['commodity_count']:>8}  {top3}{suffix}")
    print(f"{'─'*72}\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA — Consolidation CSV USGS MCS brut → format normalisé",
        epilog="""
Exemples :
  python usgs_consolidate.py --dir data/usgs/
  python usgs_consolidate.py --dir data/usgs/ --year 2023 --dry-run
  python usgs_consolidate.py --dir data/usgs/ --verbose
        """,
    )
    parser.add_argument("--dir",     required=True, help="Dossier data/usgs/")
    parser.add_argument("--year",    type=int, default=2023,
                        help="Année de production à extraire (défaut: 2023)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Afficher le résumé sans écrire le fichier")
    parser.add_argument("--verbose", action="store_true",
                        help="Afficher le détail ligne par ligne")
    args = parser.parse_args()

    data_dir = Path(args.dir)

    # Trouver le fichier MCS
    mcs_path = data_dir / f"MCS_{args.year + 1}.csv"
    if not mcs_path.exists():
        candidates = sorted(data_dir.glob("MCS_*.csv"))
        if not candidates:
            log.error("Aucun fichier MCS_*.csv trouvé dans %s", data_dir)
            sys.exit(1)
        mcs_path = candidates[-1]
        log.info("MCS trouvé : %s", mcs_path.name)

    log.info("Consolidation %s → année %d", mcs_path.name, args.year)

    data = consolidate_mcs(mcs_path, args.year, verbose=args.verbose)

    if not data:
        log.error("Aucun pays africain trouvé — vérifiez le mapping COUNTRY")
        sys.exit(1)

    print_summary(data, args.year)

    if args.dry_run:
        log.info("Dry-run — fichier non écrit")
        return

    output_path = data_dir / f"MCS_{args.year + 1}_consolidated.csv"
    write_consolidated(data, output_path, args.year)
    log.info(
        "Prêt pour ingestion :\n"
        "  python collectors/fetcher_usgs_csv.py --dir %s --indicator MIN_RES --dry-run",
        data_dir,
    )


if __name__ == "__main__":
    main()
