"""
OSA Observatory — collectors/fetcher_usgs_xls.py
Fetcher USGS Mineral Yearbook Africa (XLS/XLSX)
Source : USGS Minerals Yearbook, Volume III, Africa
URL    : https://www.usgs.gov/centers/national-minerals-information-center/africa

Indicateurs produits (un code par minerai, voir note du 2026-10-07 ci-dessous) :
  MIN_PRD_BAU — Bauxite (thousand metric tons)
  MIN_PRD_CHR — Chromite, mine output, gross weight (thousand metric tons)
  MIN_PRD_COB — Cobalt, mine output, Co content (metric tons)
  MIN_PRD_COP — Copper, mine output, Cu content (thousand metric tons)
  MIN_PRD_GOL — Gold, mine output (kilograms)
  MIN_PRD_IRN — Iron ore, gross weight (thousand metric tons)
  MIN_PRD_MAN — Manganese ore, mine output, Mn content (thousand metric tons)

============================================================
NOTE DU 2026-10-07 -- CODES D'ECRITURE CHANGES
============================================================
Ce collecteur ecrit desormais sous les codes MIN_PRD_* (famille deja
cablee : declaration p4a, collect.indicator_source, catalogue POA, collecteur
de contrebande) et non plus sous MIN_BAU/MIN_CHR/MIN_COB/MIN_COP/MIN_GOL/
MIN_IRO/MIN_MAN, crees le 2026-10-01 puis deprecies (REPLACED_BY MIN_PRD_*) :
  bauxite -> MIN_PRD_BAU   chromite -> MIN_PRD_CHR   cobalt -> MIN_PRD_COB
  cuivre  -> MIN_PRD_COP   or       -> MIN_PRD_GOL   fer    -> MIN_PRD_IRN
  manganese -> MIN_PRD_MAN
Les lignes de l'ancienne famille avaient ete generees en lisant une colonne a
indice fixe dans tous les blocs de la table : 114 des 312 lignes de couche 1
etaient une autre matiere (zinc, diamants, graphite, phosphate, charbon,
petrole, plomb) et ont ete purgees avant ce rechargement.
La partie "CORRECTIF DU 2026-09-30" ci-dessous decrit l'origine du collecteur ;
ses mentions de MIN_BAU et al. designent les anciens noms.
============================================================

============================================================
CORRECTIF DU 2026-09-30 -- A LIRE AVANT TOUTE MODIFICATION
============================================================
L'ancienne version de ce fichier annoncait dans son en-tete produire
MIN_BAU/MIN_CHR/MIN_COB/MIN_COP/MIN_GOL/MIN_IRO/MIN_MAN (7 codes), mais
COLUMN_MAP les redirigeait en realite vers seulement 3 codes deja actifs
dans le score ISA (MIN_VAL, MIN_EXP, MIN_RES, poids 9,09% chacun dans
SOV_PMIN) :
  MIN_VAL <- bauxite OU or OU manganese (le premier trouve, les 2 autres
             perdus silencieusement -- build_column_mapping ecrasait
             tout code deja mappe)
  MIN_EXP <- chromite OU cuivre
  MIN_RES <- cobalt OU fer
Resultat : MIN_EXP ("Exportations minieres") et MIN_RES ("Valeur des
reserves minieres") contenaient en realite de la PRODUCTION d'un seul
minerai arbitraire (celui rencontre en premier dans le fichier Excel de
chaque annee) -- ni des exportations, ni des reserves. MIN_VAL ("Valeur
ajoutee miniere / PIB") melangeait ses 329 vraies lignes WB avec 48
lignes de production d'un minerai au hasard.

Purge et separation effectuees le 2026-09-30 (voir
fix_usgs_mineraux_20260930.sql, suivi interne du projet) :
  - MIN_VAL/MIN_EXP/MIN_RES CONSERVES comme agregats legitimes
    (MIN_VAL : WB, 329 lignes ; MIN_EXP/MIN_RES : USGS consolide,
    31 pays/2023, via fetcher_usgs_csv.py -- collecteur distinct) --
    leurs 224 lignes contaminees (48+137+39) par ce bug ont ete
    retirees apres sauvegarde.
  - 7 nouveaux indicateurs crees dans rf.indicators (MIN_BAU et al.),
    PAS ajoutes au score ISA actif (decision de gouvernance separee
    a prendre) -- ce fichier les alimente desormais correctement,
    un code par minerai, sans ecrasement.

Deux autres corrections structurelles :
  1. Detection de feuille par CONTENU ("PRODUCTION OF SELECTED MINERAL
     COMMODITIES"), plus par nom d'onglet -- celui-ci variait sans
     coherence d'une annee a l'autre (Table04a, T4, "Table 4", Table3
     selon le fichier) et l'ancien code tombait presque toujours sur
     la derniere feuille par defaut au lieu de la bonne, silencieusement.
     Teste sur les 17 fichiers disponibles (2002-2021, hors Afrique du
     Nord/Moyen-Orient) : 17/17 detectes correctement par ce mecanisme.
     NOTE (01/10/2026) : ma.indicator_values est partitionnee par annee,
     la plus ancienne partition commence en 2010 (comme tous les autres
     indicateurs de ce chantier) -- les fichiers 2002-2009 sont donc
     exclus de la collecte reelle malgre une detection de feuille
     fonctionnelle. YEAR_MIN=2010 ci-dessous, pas 2002.
  2. Resolution des pays via collectors/country_resolver.py (meme
     module que ACLED/UCDP), avec controle de couverture -- l'ancien
     COUNTRY_MAP en dur n'a pas ete audite pays par pays lors de ce
     correctif (contrairement a ACLED/UCDP) faute de temps ; le
     controle de couverture signalera tout pays manquant au prochain
     lancement plutot que de le perdre en silence comme avant.
  3. source_id resolu dynamiquement (USGS, code 'USGS') + ON CONFLICT
     DO UPDATE -- l'ancien code n'ecrivait jamais source_id, rejete par
     chk_l1_source_id_not_null (ces lignes ne pouvaient en fait jamais
     s'inserer sans l'ancien fallback silencieux qui les classait sous
     UNESCO via le patch de masse Sprint 9, meme defaut que partout
     ailleurs dans ce chantier).
============================================================

Fichiers attendus (noms USGS officiels, places tels quels dans --dir) :
  myb3-sum-YYYY-africa.xls           (2010-2013, 2015)
  myb3-YYYY-africa.xlsx / myb3-sum-YYYY-africa.xlsx / myb3-YYYY-africa-sum.xlsx
                                      (2014, 2016-2021, nommage variable)
  Fichiers 2002-2009 (africa0{2,3,4}.xls, myb3-sum-2005..2009-africa.xls)
  NON COLLECTABLES : ma.indicator_values n'a aucune partition avant 2010
  (voir note ci-dessus). Conserves pour reference mais toujours ignores
  par ce script (YEAR_MIN=2010).
Telechargement : https://www.usgs.gov/centers/national-minerals-information-center/africa

Usage :
  python collectors/fetcher_usgs_xls.py --dir data/raw/pmin --dry-run
  python collectors/fetcher_usgs_xls.py --dir data/raw/pmin
  python collectors/fetcher_usgs_xls.py --file data/raw/pmin/myb3-sum-2010-africa.xls --dry-run
"""
from __future__ import annotations
import argparse, logging, os, re, sys
from pathlib import Path
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parent))
from country_resolver import CountryResolver, CoverageError  # noqa: E402

load_dotenv()

logging.basicConfig(level=os.getenv("OSA_LOG_LEVEL","INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s")
log = logging.getLogger("fetcher_usgs_xls")

YEAR_MIN, YEAR_MAX, LAYER_RAW, BATCH_SIZE = 2010, 2024, 1, 500

# Phrase distinctive recherchee dans les 3 premieres lignes de chaque
# feuille pour identifier la table de production minerale, quel que
# soit le nom de l'onglet (variable d'une annee a l'autre).
SHEET_MARKER = "PRODUCTION OF SELECTED MINERAL"

# ── Mapping colonnes USGS → codes ISA, UN CODE PAR MINERAI ───────────
# Chaque entree : (mots-cles dans l'en-tete concatene, osa_code, multiplicateur)
# Plus aucun partage de code entre minerais -- c'etait le bug corrige.
COLUMN_MAP = [
    (["bauxite"],                  "MIN_PRD_BAU", 1.0),    # thousand metric tons
    (["chromite","chrome"],        "MIN_PRD_CHR", 1.0),    # thousand metric tons
    (["cobalt","co content"],      "MIN_PRD_COB", 1.0),    # metric tons
    (["copper","cu content"],      "MIN_PRD_COP", 1.0),    # thousand metric tons
    (["gold","au content"],        "MIN_PRD_GOL", 1.0),    # kilograms
    (["iron ore","usable ore"],    "MIN_PRD_IRN", 1.0),    # thousand metric tons
    (["manganese","mn content"],   "MIN_PRD_MAN", 1.0),    # thousand metric tons
]

def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST","localhost"),
        port=int(os.getenv("OSA_DB_PORT",5432)),
        dbname=os.getenv("OSA_DB_NAME","osa_db"),
        user=os.getenv("OSA_DB_USER","postgres"),
        password=os.getenv("OSA_DB_PASS",""),
    )

def extract_year(filepath: str) -> int | None:
    """Extrait l'année depuis le nom de fichier."""
    m = re.search(r'(20\d{2})', Path(filepath).name)
    if m:
        return int(m.group(1))
    return None

def find_production_sheet(filepath: str) -> str | None:
    """
    Trouve le nom de la feuille contenant la table de production
    minerale, en cherchant SHEET_MARKER dans son contenu -- le nom de
    l'onglet varie sans coherence d'une annee a l'autre (Table04a, T4,
    "Table 4", Table3 selon le fichier), on ne peut pas s'y fier.
    """
    ext = Path(filepath).suffix.lower()
    if ext == ".xls":
        xl = pd.ExcelFile(filepath, engine="xlrd")
    else:
        xl = pd.ExcelFile(filepath, engine="openpyxl")

    for name in xl.sheet_names:
        try:
            df = xl.parse(name, header=None, nrows=3)
        except Exception:
            continue
        txt = " ".join(str(v) for v in df.values.flatten() if v is not None).upper()
        if SHEET_MARKER in txt:
            return name
    return None

def read_production_table(filepath: str, sheet_name: str) -> list:
    """Lit la feuille identifiee, retourne une liste de lignes (listes)."""
    ext = Path(filepath).suffix.lower()
    if ext == ".xls":
        import xlrd
        wb = xlrd.open_workbook(str(filepath))
        sheet = wb.sheet_by_name(sheet_name)
        rows = [sheet.row_values(i) for i in range(sheet.nrows)]
    else:
        import openpyxl
        wb = openpyxl.load_workbook(str(filepath), read_only=True, data_only=True)
        sheet = wb[sheet_name]
        rows = [list(r) for r in sheet.iter_rows(values_only=True)]
    return rows

def find_header_and_data(rows: list) -> tuple[int, int]:
    """
    Trouve la ligne 'Country' (debut des donnees) et le debut des
    lignes d'en-tete. Retourne (header_start, data_start).
    """
    country_row = None
    for i, row in enumerate(rows):
        if row and str(row[0]).strip().lower().startswith("country"):
            country_row = i
            break
    if country_row is None:
        raise ValueError("Ligne 'Country' non trouvee")
    return max(0, country_row - 6), country_row + 1

def build_column_mapping(rows: list, header_start: int, data_start: int) -> dict:
    """
    Construit le mapping col_index -> (osa_code, multiplier) en
    analysant les lignes d'en-tete. Un seul index de colonne par
    minerai (le premier trouve pour ce minerai precis) -- mais
    contrairement a l'ancien code, chaque minerai a desormais son
    PROPRE osa_code, donc plus aucun ecrasement entre minerais
    differents.
    """
    col_labels = {}
    ncols = max((len(r) for r in rows[header_start:data_start]), default=0)
    for i in range(ncols):
        parts = []
        for r in range(header_start, data_start):
            if r >= len(rows):
                continue
            val = rows[r][i] if i < len(rows[r]) else None
            if val and str(val).strip():
                parts.append(str(val).strip().lower())
        col_labels[i] = " ".join(parts)

    mapping = {}
    mapped_codes = set()
    for col_idx, label in col_labels.items():
        for keywords, osa_code, mult in COLUMN_MAP:
            if osa_code in mapped_codes:
                continue
            if any(kw in label for kw in keywords):
                mapping[col_idx] = (osa_code, mult)
                mapped_codes.add(osa_code)
                break
    return mapping

def parse_value(val) -> float | None:
    """Nettoie et convertit une valeur USGS."""
    if val is None:
        return None
    s = str(val).strip()
    if s in ["--", "---", "NA", "W", "e", "", "None", "nan"]:
        return None
    s = re.sub(r'[a-zA-Z,\s]+$', '', s).strip()
    s = s.replace(",", "")
    try:
        return float(s)
    except (ValueError, TypeError):
        return None

def find_country_positions(rows: list) -> list[int]:
    """Retourne les index de TOUTES les lignes 'Country' (debut de chaque
    bloc). La plupart des fichiers USGS empilent plusieurs blocs dans une
    seule feuille : des blocs consecutifs au MEME en-tete sont la suite
    du meme tableau coupe par la pagination d'impression (les pays se
    repartissent sans chevauchement), mais des blocs a en-tete DIFFERENT
    sont une table de minerais distincte -- vus le 2026-10-01 sur
    myb3-sum-2012-africa.xls : blocs 1+2 = bauxite/aluminium/chromite/
    cobalt/cuivre, blocs 3+4 = zinc/diamant/ciment/graphite/phosphate.
    Traiter toute la feuille avec un seul mapping de colonnes (comme
    l'ancien code) attribuerait a tort les valeurs des blocs 3+4 aux
    minerais des blocs 1+2 -- pas juste une perte de donnees, une vraie
    donnee mal attribuee."""
    return [i for i, row in enumerate(rows)
            if row and str(row[0]).strip().lower().startswith("country")]

def resolve_country_name(resolver: CountryResolver, raw_name: str, max_trim: int = 2):
    """
    Resout un nom de pays en essayant la chaine telle quelle, puis en
    retirant progressivement 1 puis 2 caracteres finaux -- les fichiers
    USGS collent parfois une lettre de note directement au nom
    ("Kenyae", "Zimbabwee", "Congo (Kinshasa)e", "Morocco and Western
    Saharae") sans espace. Un simple retrait par expression reguliere
    des lettres minuscules finales (ancienne approche) echoue sur les
    noms entierement en minuscules apres la majuscule initiale
    ("Zimbabwee" -> chaine vide) : on essaie donc un retrait progressif
    et on s'arrete au premier succes, plutot qu'un decoupage aveugle.
    """
    name = raw_name.strip()
    for trim in range(0, max_trim + 1):
        candidate = name[:len(name) - trim] if trim > 0 else name
        candidate = candidate.strip()
        if not candidate:
            break
        iso3, mode = resolver.resolve(candidate)
        if iso3:
            return iso3, mode
    return None, None

def parse_file(filepath: str, resolver: CountryResolver) -> list[dict]:
    """Parse un fichier USGS et retourne une liste de records.

    Traite CHAQUE bloc 'Country' separement, avec son PROPRE mapping de
    colonnes recalcule depuis son en-tete local -- voir
    find_country_positions() pour la raison (blocs a en-tetes differents
    = minerais differents, ne jamais reutiliser le mapping d'un bloc
    precedent).
    """
    year = extract_year(filepath)
    if year is None or not (YEAR_MIN <= year <= YEAR_MAX):
        log.warning("  Annee %s hors plage [%d,%d] -- ignore", year, YEAR_MIN, YEAR_MAX)
        return []

    log.info("  Parsing %s (annee %d)", Path(filepath).name, year)

    sheet_name = find_production_sheet(filepath)
    if sheet_name is None:
        log.warning("  Feuille de production non trouvee dans %s (marqueur '%s' absent) -- ignore",
                    filepath, SHEET_MARKER)
        return []
    log.debug("  Feuille identifiee : %s", sheet_name)

    rows = read_production_table(filepath, sheet_name)
    country_positions = find_country_positions(rows)
    if not country_positions:
        log.warning("  Aucune ligne 'Country' trouvee dans %s (feuille %s)", filepath, sheet_name)
        return []
    log.debug("  %d bloc(s) 'Country' trouve(s) aux lignes %s", len(country_positions), country_positions)

    records = []
    resolved_cache: dict[str, tuple] = {}
    non_resolus = set()

    for bi, pos in enumerate(country_positions):
        header_start = max(0, pos - 6)
        data_start = pos + 1
        data_end = country_positions[bi + 1] if bi + 1 < len(country_positions) else len(rows)

        col_map = build_column_mapping(rows, header_start, data_start)
        if not col_map:
            log.debug("  Bloc %d (lignes %d-%d) : aucune colonne minerale reconnue -- ignore",
                      bi + 1, pos, data_end)
            continue

        for row in rows[data_start:data_end]:
            if not row or not row[0]:
                continue
            raw_name = str(row[0]).strip()
            if raw_name not in resolved_cache:
                resolved_cache[raw_name] = resolve_country_name(resolver, raw_name)
            iso3, _mode = resolved_cache[raw_name]
            if not iso3:
                non_resolus.add(raw_name)
                continue

            for col_idx, (osa_code, mult) in col_map.items():
                val_raw = row[col_idx] if col_idx < len(row) else None
                val = parse_value(val_raw)
                if val is None:
                    continue
                val_final = val * mult
                if val_final < 0:
                    continue
                records.append({
                    "indicator_code": osa_code,
                    "country_iso3":   iso3,
                    "year":           year,
                    "raw_value":      val_final,
                })

    if non_resolus:
        log.debug("  Libelles non resolus vers un pays OSA (%d, normal pour les lignes de "
                  "titre/notes/totaux) : %s", len(non_resolus), ", ".join(sorted(non_resolus)[:10]))

    log.info("  -> %d enregistrements (%d pays)",
             len(records), len({r["country_iso3"] for r in records}))
    return records

def insert_to_db(conn, records: list[dict], dry_run: bool = False) -> int:
    """Insere les records en ma.indicator_values."""
    if not records:
        return 0

    df = pd.DataFrame(records)
    valid = pd.read_sql("SELECT iso3 FROM rf.countries", conn)["iso3"].tolist()
    df = df[df["country_iso3"].isin(valid)].copy()

    valid_inds = pd.read_sql(
        "SELECT code FROM rf.indicators WHERE pillar_code='PMIN'", conn
    )["code"].tolist()
    df = df[df["indicator_code"].isin(valid_inds)].copy()

    if df.empty:
        log.warning("  Aucun enregistrement valide apres filtrage")
        return 0

    if dry_run:
        for ind, grp in df.groupby("indicator_code"):
            log.info("  [DRY-RUN] %s : %d valeurs | %d pays | annees %s-%s",
                     ind, len(grp), grp["country_iso3"].nunique(),
                     grp["year"].min(), grp["year"].max())
        log.info("  [DRY-RUN] Total : %d valeurs non inserees", len(df))
        return len(df)

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mm.source_origins WHERE code = %s", ("USGS",))
        row = cur.fetchone()
        if not row:
            raise RuntimeError("mm.source_origins : code USGS introuvable")
        usgs_source_id = row[0]

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, quality_flag, confidence_score, value_status, source_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (indicator_code, country_iso3, year, layer_id, method_version_id)
        DO UPDATE SET
            raw_value        = EXCLUDED.raw_value,
            quality_flag     = EXCLUDED.quality_flag,
            confidence_score = EXCLUDED.confidence_score,
            value_status     = EXCLUDED.value_status,
            source_id        = EXCLUDED.source_id
    """
    batch = [(r["indicator_code"], r["country_iso3"], int(r["year"]),
              LAYER_RAW, float(r["raw_value"]), "OK", 0.9, "OBSERVED", usgs_source_id)
             for _, r in df.iterrows()]

    with conn.cursor() as cur:
        execute_batch(cur, sql, batch, page_size=BATCH_SIZE)
    conn.commit()
    log.info("  -> %d inseres (source USGS)", len(batch))
    return len(batch)

def main():
    parser = argparse.ArgumentParser(description="OSA Fetcher USGS Mineral Yearbook")
    parser.add_argument("--dir",     type=str, default=None,
                        help="Dossier contenant les fichiers USGS")
    parser.add_argument("--file",    type=str, default=None,
                        help="Fichier USGS unique a traiter")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.dir and not args.file:
        parser.print_help()
        sys.exit(1)

    log.info("="*60)
    log.info("OSA Fetcher USGS Mineral Yearbook")
    log.info("  Dry-run : %s", args.dry_run)
    log.info("="*60)

    files = []
    if args.file:
        files = [args.file]
    else:
        d = Path(args.dir)
        files = sorted([
            str(f) for f in d.iterdir()
            if f.suffix.lower() in [".xls", ".xlsx"]
            and ("africa" in f.name.lower())
            and "me-na" not in f.name.lower()
            and "middle" not in f.name.lower()
            and "areacodes" not in f.name.lower()
            and "elements" not in f.name.lower()
            and "itemcodes" not in f.name.lower()
        ])

    log.info("  Fichiers trouves : %d", len(files))
    if not files:
        log.warning("  Aucun fichier USGS trouve.")
        sys.exit(1)

    conn = get_pg_conn()
    try:
        resolver = CountryResolver.from_db(conn)

        all_records = []
        for fp in files:
            try:
                records = parse_file(fp, resolver)
                all_records.extend(records)
            except Exception as e:
                log.error("  Erreur sur %s : %s", fp, e)

        log.info("Total enregistrements prepares : %d", len(all_records))

        if not all_records:
            log.warning("Aucune donnee extraite.")
            sys.exit(1)

        seen = set()
        unique_records = []
        for r in all_records:
            key = (r["indicator_code"], r["country_iso3"], r["year"])
            if key not in seen:
                seen.add(key)
                unique_records.append(r)
        log.info("Apres deduplication : %d enregistrements", len(unique_records))

        n = insert_to_db(conn, unique_records, dry_run=args.dry_run)
    finally:
        conn.close()

    df = pd.DataFrame(unique_records)
    print("\n" + "="*60)
    print("RAPPORT USGS MINERAL YEARBOOK")
    print("="*60)
    print(f"Mode     : {'DRY-RUN' if args.dry_run else 'COLLECT'}")
    print(f"Fichiers : {len(files)}")
    print(f"Prepares : {len(unique_records)}")
    print(f"Inseres  : {n}")
    if not df.empty:
        print("\nPar indicateur :")
        for ind, grp in df.groupby("indicator_code"):
            print(f"  {ind:<12} : {len(grp):>5} val | "
                  f"{grp['country_iso3'].nunique()} pays | "
                  f"{grp['year'].min()}-{grp['year'].max()}")
    print("="*60)

if __name__ == "__main__":
    main()
