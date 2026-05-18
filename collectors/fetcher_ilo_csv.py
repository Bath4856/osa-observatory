"""
============================================================
OSA Observatory
collectors/fetcher_ilo_csv.py — Fetcher ILO (CSV.GZ)
============================================================
Indicateurs couverts (pilier PECO) :

  ECO_INFORMAL_RATE   Taux d'emploi informel total (% emploi total)
                      Source : SDG_0831_SEX_ECO_RT_A
                      Filtre : SEX_T + ECO_SECTOR_TOTAL
                      Direction : − (plus c'est haut, moins la souveraineté formelle est forte)

  ECO_INFORMAL_NAG    Taux d'emploi informel hors agriculture (% emploi non-agricole)
                      Source : SDG_0831_SEX_ECO_RT_A
                      Filtre : SEX_T + ECO_SECTOR_NAG
                      Direction : − (informalité urbaine/industrielle actionnable)

  ECO_INFORMAL_NB     Nombre de travailleurs informels (milliers)
                      Source : EMP_NIFL_SEX_ECO_NB_A
                      Filtre : SEX_T + ECO_SECTOR_TOTAL
                      Direction : − (volume absolu)

  ECO_INFORMAL_MICRO  Part emploi informel dans micro-entreprises 1–4 employés (%)
                      Source : EMP_NIFL_SEX_ECO_EST_NB_A
                      Filtre : SEX_T + ECO_SECTOR_TOTAL + EST_AGGREGATE_S1-4
                      Direction : − (proxy fragmentation productive)

Contexte analytique OSA :
  Corruption et économie informelle sont des facteurs de distorsion
  transversaux qui affectent tous les piliers ISA. Ils ne constituent
  pas des piliers autonomes mais des forces de distorsion souveraine
  mesurées par leurs effets conséquentiels sur PECO, PMON, PGEO, PMIN.

  ECO_INFORMAL_RATE et ECO_INFORMAL_NAG alimenteront l'indicateur
  calculé L3 ECO_FORMAL_TRAJECTORY (variation 3 ans glissants de la
  formalisation) — proxy du delta+ de souveraineté économique.

Sources ILO :
  https://rplumber.ilo.org/data/indicator?id=SDG_0831_SEX_ECO_RT_A&format=.csv.gz
  https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_NB_A&format=.csv.gz
  https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_EST_NB_A&format=.csv.gz

Placer les fichiers dans : data/raw/peco/ilo/

Usage :
  python collectors/fetcher_ilo_csv.py --dir data/raw/peco/ilo --dry-run
  python collectors/fetcher_ilo_csv.py --dir data/raw/peco/ilo
  python collectors/fetcher_ilo_csv.py --dir data/raw/peco/ilo --indicator ECO_INFORMAL_RATE
  python collectors/fetcher_ilo_csv.py --dir data/raw/peco/ilo --list-missing
============================================================
"""
from __future__ import annotations

import argparse
import gzip
import logging
import os
import sys
from pathlib import Path
from typing import Optional

import pandas as pd
from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3

load_dotenv()

# ── Fichiers sources ILO ──────────────────────────────────────────────────────

ILO_FILES: dict[str, str] = {
    "SDG_0831":   "SDG_0831_SEX_ECO_RT_A.csv.gz",   # Taux emploi informel (%)
    "EMP_NB":     "EMP_NIFL_SEX_ECO_NB_A.csv.gz",   # Nombre travailleurs informels
    "EMP_EST":    "EMP_NIFL_SEX_ECO_EST_NB_A.csv.gz",# Par taille d'entreprise
}

# URL de téléchargement (pour documentation)
ILO_URLS: dict[str, str] = {
    "SDG_0831": "https://rplumber.ilo.org/data/indicator?id=SDG_0831_SEX_ECO_RT_A&format=.csv.gz",
    "EMP_NB":   "https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_NB_A&format=.csv.gz",
    "EMP_EST":  "https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_EST_NB_A&format=.csv.gz",
}

# ── Mapping indicateurs OSA ───────────────────────────────────────────────────

ILO_INDICATOR_MAP: dict = {
    "ECO_INFORMAL_RATE": {
        "file":       "SDG_0831",
        "sex":        "SEX_T",
        "classif1":   "ECO_SECTOR_TOTAL",
        "classif2":   None,
        "name_fr":    "Taux emploi informel total (% emploi total) — ILO SDG 8.3.1",
        "direction":  "-",
        "unit":       "PCT",
        "note":       (
            "SDG 8.3.1 — Part de l'emploi informel dans l'emploi total. "
            "Valeur élevée = pression sur la souveraineté économique formelle. "
            "10 pays africains manquants imputés par MICE (CAF, COG, DZA, ERI, GIN, GNQ, LBY, MAR, SSD, STP)."
        ),
    },
    "ECO_INFORMAL_NAG": {
        "file":       "SDG_0831",
        "sex":        "SEX_T",
        "classif1":   "ECO_SECTOR_NAG",
        "classif2":   None,
        "name_fr":    "Taux emploi informel hors agriculture (% emploi non-agricole) — ILO SDG 8.3.1",
        "direction":  "-",
        "unit":       "PCT",
        "note":       (
            "Taux d'emploi informel dans les secteurs non-agricoles. "
            "Distingue l'informalité structurelle rurale (agricole) de "
            "l'informalité urbaine et industrielle actionnable. "
            "Couverture : 22 pays africains — 32 imputés par MICE."
        ),
    },
    "ECO_INFORMAL_NB": {
        "file":       "EMP_NB",
        "sex":        "SEX_T",
        "classif1":   "ECO_SECTOR_TOTAL",
        "classif2":   None,
        "name_fr":    "Nombre de travailleurs informels (milliers) — ILO EMP_NIFL",
        "direction":  "-",
        "unit":       "THOUS",
        "note":       (
            "Nombre absolu de travailleurs en emploi informel (milliers). "
            "Complément de ECO_INFORMAL_RATE — capte l'ampleur absolue "
            "indépendamment du taux. Valeur en milliers de personnes."
        ),
    },
    "ECO_INFORMAL_MICRO": {
        "file":       "EMP_EST",
        "sex":        "SEX_T",
        "classif1":   "ECO_SECTOR_TOTAL",
        "classif2":   "EST_AGGREGATE_S1-4",
        "name_fr":    "Part emploi informel micro-entreprises 1–4 employés (nb) — ILO EMP_NIFL_EST",
        "direction":  "-",
        "unit":       "THOUS",
        "note":       (
            "Nombre de travailleurs informels dans les micro-entreprises "
            "(1 à 4 employés). Proxy de la fragmentation productive — "
            "plus ce ratio est élevé, plus l'économie informelle est "
            "atomisée et difficile à formaliser. 38 pays couverts."
        ),
    },
}

# ── Colonnes ILO standard ─────────────────────────────────────────────────────

ILO_COLS = {
    "ref_area":  "iso3",
    "time":      "year",
    "obs_value": "value",
}


class ILOFetcher(BaseFetcher):

    PROVIDER_CODE = "ILO"
    ENDPOINT_CODE = "ILO_CSV_GZ"
    INDICATOR_MAP = ILO_INDICATOR_MAP

    def __init__(
        self,
        data_dir: str = "data/raw/peco/ilo",
        dry_run:  bool = False,
    ) -> None:
        super().__init__(dry_run=dry_run)
        self.data_dir = Path(data_dir)
        self._cache: dict[str, pd.DataFrame] = {}

    # ── Chargement fichier ILO gz ─────────────────────────────────────────────

    def _load_file(self, file_key: str) -> Optional[pd.DataFrame]:
        """Charge et met en cache un fichier ILO CSV.GZ."""
        if file_key in self._cache:
            return self._cache[file_key]

        filename = ILO_FILES[file_key]
        path = self.data_dir / filename

        if not path.exists():
            # Essayer avec le nom téléchargé (contient date dans le nom)
            candidates = list(self.data_dir.glob(f"*{file_key.replace('_','')}*.gz")) + \
                         list(self.data_dir.glob(f"*{file_key}*.gz")) + \
                         list(self.data_dir.glob("SDG_0831*.gz" if file_key == "SDG_0831" else
                                                  "EMP_NIFL_SEX_ECO_NB*.gz" if file_key == "EMP_NB" else
                                                  "EMP_NIFL_SEX_ECO_EST*.gz"))
            if candidates:
                path = candidates[0]
                self.log.info("Fichier trouvé : %s", path.name)
            else:
                self.log.warning(
                    "Fichier ILO absent : %s\n"
                    "  Télécharger depuis : %s\n"
                    "  Placer dans : %s",
                    filename, ILO_URLS.get(file_key, "N/A"), self.data_dir
                )
                return None

        try:
            with gzip.open(path, "rt", encoding="utf-8") as f:
                df = pd.read_csv(f, low_memory=False)
            self.log.info(
                "Chargé %s : %d lignes, %d colonnes",
                path.name, len(df), len(df.columns)
            )
            self._cache[file_key] = df
            return df
        except Exception as e:
            self.log.error("Erreur lecture %s : %s", path.name, e)
            return None

    # ── Extraction indicateur ─────────────────────────────────────────────────

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Extrait un indicateur depuis le fichier ILO correspondant."""

        file_key = config["file"]
        df = self._load_file(file_key)
        if df is None:
            return []

        # Filtres de base
        mask = (
            df["ref_area"].isin(AFRICAN_ISO3) &
            df["time"].between(year_from, year_to) &
            df["obs_value"].notna()
        )

        # Filtre sex
        if config.get("sex") and "sex" in df.columns:
            mask &= (df["sex"] == config["sex"])

        # Filtre classif1
        if config.get("classif1") and "classif1" in df.columns:
            mask &= (df["classif1"] == config["classif1"])

        # Filtre classif2
        if config.get("classif2") and "classif2" in df.columns:
            mask &= (df["classif2"] == config["classif2"])

        df_filtered = df[mask].copy()

        if df_filtered.empty:
            self.log.warning(
                "%s → aucune donnée après filtres (sex=%s, classif1=%s, classif2=%s)",
                osa_code, config.get("sex"), config.get("classif1"), config.get("classif2")
            )
            return []

        # Dédoublonnage — garder la valeur la plus récente par pays/année
        df_filtered = df_filtered.sort_values("time").drop_duplicates(
            subset=["ref_area", "time"], keep="last"
        )

        # Conversion en DataRecords
        records: list[DataRecord] = []
        for _, row in df_filtered.iterrows():
            try:
                value = float(row["obs_value"])
                if pd.isna(value):
                    continue
                records.append({
                    "iso3":  str(row["ref_area"]).strip().upper(),
                    "year":  int(row["time"]),
                    "value": round(value, 6),
                })
            except (ValueError, TypeError):
                continue

        self.log.info(
            "%s → %d enregistrements (%d pays, %d–%d)",
            osa_code, len(records),
            len(set(r["iso3"] for r in records)),
            year_from, year_to,
        )
        return records

    # ── Rapport de couverture ─────────────────────────────────────────────────

    def report_coverage(self, year_from: int = 2010, year_to: int = 2024) -> None:
        """Affiche la couverture par indicateur et pays manquants."""
        self.log.info("=" * 60)
        self.log.info("RAPPORT DE COUVERTURE ILO — %d–%d", year_from, year_to)
        self.log.info("=" * 60)

        for osa_code, config in self.INDICATOR_MAP.items():
            records = self.fetch_indicator(osa_code, config, year_from, year_to)
            if not records:
                self.log.warning("%s → AUCUNE DONNÉE", osa_code)
                continue

            pays_couverts = set(r["iso3"] for r in records)
            manquants = set(AFRICAN_ISO3) - pays_couverts
            nb_total = len(records)
            nb_pays = len(pays_couverts)

            # Distribution temporelle
            years_per_country = {}
            for r in records:
                years_per_country.setdefault(r["iso3"], 0)
                years_per_country[r["iso3"]] += 1

            avg_years = sum(years_per_country.values()) / len(years_per_country) if years_per_country else 0

            self.log.info(
                "%s : %d lignes | %d/54 pays | %.1f années/pays moy",
                osa_code, nb_total, nb_pays, avg_years
            )
            if manquants:
                self.log.info(
                    "  Manquants (%d) : %s",
                    len(manquants), ", ".join(sorted(manquants))
                )

    # ── run() ─────────────────────────────────────────────────────────────────

    def run(
        self,
        year_from:        int = 2010,
        year_to:          int = 2024,
        indicator_filter: Optional[str] = None,
    ) -> dict:
        results = {"ok": [], "failed": [], "skipped": []}
        t_start = __import__("time").time()

        indicators = (
            {indicator_filter: self.INDICATOR_MAP[indicator_filter]}
            if indicator_filter and indicator_filter in self.INDICATOR_MAP
            else self.INDICATOR_MAP
        )

        self.log.info("=" * 60)
        self.log.info("OSA — Fetcher ILO CSV")
        self.log.info("Répertoire : %s", self.data_dir)
        self.log.info("Indicateurs : %d | Années : %d–%d", len(indicators), year_from, year_to)
        self.log.info("Dry-run : %s", self.dry_run)
        self.log.info("=" * 60)

        for osa_code, config in indicators.items():
            self.log.info("── %s (%s) ──", osa_code, config["name_fr"])
            try:
                records = self.fetch_indicator(osa_code, config, year_from, year_to)

                if not records:
                    self.log.warning(
                        "%s → 0 enregistrements — vérifier fichier %s",
                        osa_code, ILO_FILES.get(config["file"], "inconnu")
                    )
                    results["skipped"].append(osa_code)
                    continue

                inserted, rejected = self.insert_records(osa_code, records)
                self.log.info(
                    "%s → +%d insérés / %d rejetés",
                    osa_code, inserted, rejected
                )
                results["ok"].append(osa_code)

                duration_ms = int((__import__("time").time() - t_start) * 1000)
                self.log_ingestion(
                    osa_code, year_to, "SUCCESS", inserted, rejected, duration_ms
                )

            except Exception as exc:
                self.log.error("%s → ERREUR : %s", osa_code, exc, exc_info=True)
                results["failed"].append(osa_code)

        # Résumé
        elapsed = round(__import__("time").time() - t_start, 1)
        self.log.info("=" * 60)
        self.log.info(
            "ILO terminé en %ss | OK:%d SKIP:%d FAIL:%d",
            elapsed, len(results["ok"]), len(results["skipped"]), len(results["failed"])
        )
        if results["skipped"]:
            self.log.warning(
                "Indicateurs skippés (fichier absent) : %s",
                ", ".join(results["skipped"])
            )
        if results["failed"]:
            self.log.error("Échecs : %s", ", ".join(results["failed"]))
        self.log.info("=" * 60)
        return results


# ── Point d'entrée ────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — ILO Emploi Informel (CSV.GZ)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs produits (pilier PECO) :
  ECO_INFORMAL_RATE    Taux emploi informel total (%)            SDG 8.3.1
  ECO_INFORMAL_NAG     Taux emploi informel hors agriculture (%) SDG 8.3.1
  ECO_INFORMAL_NB      Nb travailleurs informels (milliers)      EMP_NIFL
  ECO_INFORMAL_MICRO   Nb travailleurs micro-entreprises 1-4     EMP_NIFL_EST

Fichiers requis dans --dir :
  SDG_0831_SEX_ECO_RT_A.csv.gz      → ECO_INFORMAL_RATE + ECO_INFORMAL_NAG
  EMP_NIFL_SEX_ECO_NB_A.csv.gz      → ECO_INFORMAL_NB
  EMP_NIFL_SEX_ECO_EST_NB_A.csv.gz  → ECO_INFORMAL_MICRO

Téléchargement :
  https://rplumber.ilo.org/data/indicator?id=SDG_0831_SEX_ECO_RT_A&format=.csv.gz
  https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_NB_A&format=.csv.gz
  https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_EST_NB_A&format=.csv.gz

Exemples :
  python fetcher_ilo_csv.py --dir data/raw/peco/ilo --dry-run
  python fetcher_ilo_csv.py --dir data/raw/peco/ilo
  python fetcher_ilo_csv.py --dir data/raw/peco/ilo --indicator ECO_INFORMAL_RATE
  python fetcher_ilo_csv.py --dir data/raw/peco/ilo --list-missing
  python fetcher_ilo_csv.py --dir data/raw/peco/ilo --coverage
        """
    )
    parser.add_argument("--dir",          type=str, default="data/raw/peco/ilo",
                        help="Répertoire contenant les fichiers ILO CSV.GZ")
    parser.add_argument("--from",         type=int, dest="year_from", default=2010)
    parser.add_argument("--to",           type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",    type=str, default=None,
                        help="Indicateur unique : ECO_INFORMAL_RATE | ECO_INFORMAL_NAG | ECO_INFORMAL_NB | ECO_INFORMAL_MICRO")
    parser.add_argument("--dry-run",      action="store_true",
                        help="Simule sans écriture en base")
    parser.add_argument("--list-missing", action="store_true",
                        help="Liste les fichiers présents/absents")
    parser.add_argument("--coverage",     action="store_true",
                        help="Rapport de couverture par pays/indicateur")
    args = parser.parse_args()

    if args.list_missing:
        data_dir = Path(args.dir)
        print(f"\nFichiers ILO dans {data_dir} :")
        files = [
            ("SDG_0831_SEX_ECO_RT_A.csv.gz",     "Taux emploi informel (%)  → ECO_INFORMAL_RATE + ECO_INFORMAL_NAG"),
            ("EMP_NIFL_SEX_ECO_NB_A.csv.gz",      "Nb travailleurs informels → ECO_INFORMAL_NB"),
            ("EMP_NIFL_SEX_ECO_EST_NB_A.csv.gz",  "Par taille entreprise     → ECO_INFORMAL_MICRO"),
        ]
        for fname, desc in files:
            status = "✓ présent" if (data_dir / fname).exists() else "○ absent"
            print(f"  {status}  {fname:45s} {desc}")
        print(f"\nCouverture attendue : 43–44/54 pays africains pour SDG_0831")
        print(f"Pays manquants connus : CAF, COG, DZA, ERI, GIN, GNQ, LBY, MAR, SSD, STP")
        print(f"→ Ces pays seront imputés par MICE lors de l'étape L2.")
        return

    logging.basicConfig(
        level=os.getenv("OSA_LOG_LEVEL", "INFO"),
        format="%(asctime)s | %(levelname)-8s | %(message)s",
    )

    fetcher = ILOFetcher(
        data_dir=args.dir,
        dry_run=args.dry_run,
    )

    try:
        fetcher.connect()

        if args.coverage:
            fetcher.report_coverage(args.year_from, args.year_to)
            return

        result = fetcher.run(args.year_from, args.year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)

    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
