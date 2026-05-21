"""
OSA Observatory — fix_sipri_fetcher_reference_table.py
Sprint 9 — Mai 2026

Migre fetcher_sipri_csv.py et fetcher_sipri_milex.py pour lire
les labels régionaux SIPRI depuis collect.reference_classifications
au lieu des listes codées en dur SIPRI_REGION_LABELS et SUBREGIONS.

Deux actions :
1. Insérer les labels régionaux SIPRI dans collect.reference_classifications
2. Patcher les deux fetchers pour lire depuis la table
"""
import os
import sys
from pathlib import Path

# ── 1. Insertion SQL dans reference_classifications ───────────────────────────

SQL = """
INSERT INTO collect.reference_classifications
    (source_code, country_iso3, classification, valid_from, metadata, source_url)
VALUES
-- Labels régionaux SIPRI à ignorer (pas des pays)
-- country_iso3 = NULL car ce sont des agrégats, pas des pays
('SIPRI_LABELS', NULL, 'africa',              2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'north africa',         2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'sub-saharan africa',   2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'central africa',       2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'east africa',          2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'west africa',          2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'southern africa',      2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'middle east',          2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'europe',               2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'americas',             2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'asia & oceania',       2010, '{"type":"region_label","action":"skip"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'Asia & Oceania',       2010, '{"type":"region_label","action":"skip","case":"mixed"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'sub-Saharan Africa',   2010, '{"type":"region_label","action":"skip","case":"mixed"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'Africa',               2010, '{"type":"region_trigger","action":"enter_africa"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'Europe',               2010, '{"type":"region_trigger","action":"exit_africa"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'Americas',             2010, '{"type":"region_trigger","action":"exit_africa"}', 'https://www.sipri.org/databases/milex'),
('SIPRI_LABELS', NULL, 'Middle East',          2010, '{"type":"region_trigger","action":"exit_africa"}', 'https://www.sipri.org/databases/milex')
ON CONFLICT (source_code, country_iso3, classification, valid_from) DO NOTHING;
"""

# Appliquer via psycopg2
import psycopg2
from dotenv import load_dotenv
load_dotenv()

try:
    conn = psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "127.0.0.1"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
    )
    with conn.cursor() as cur:
        cur.execute(SQL)
        print(f"OK -- {cur.rowcount} labels SIPRI insérés dans reference_classifications")
    conn.commit()
    conn.close()
except Exception as e:
    print(f"WARN -- DB inaccessible : {e}")
    print("  Exécuter manuellement le SQL ci-dessus")

# ── 2. Patch fetcher_sipri_csv.py ─────────────────────────────────────────────

SIPRI_CSV = Path("collectors/fetcher_sipri_csv.py")
content = SIPRI_CSV.read_text(encoding="utf-8")

OLD_REGION = '''# ── Lignes de sous-regions SIPRI a ignorer ────────────────
SIPRI_REGION_LABELS = {
    "africa", "north africa", "sub-saharan africa",
    "central africa", "east africa", "west africa",
    "southern africa", "middle east", "europe",'''

NEW_REGION = '''# ── Lignes de sous-regions SIPRI a ignorer ────────────────
# Source : collect.reference_classifications (source_code='SIPRI_LABELS')
# Fallback sur liste locale si DB inaccessible
def _load_sipri_region_labels() -> set:
    """Charge les labels régionaux SIPRI depuis collect.reference_classifications."""
    try:
        import psycopg2, os
        from dotenv import load_dotenv
        load_dotenv()
        conn = psycopg2.connect(
            host=os.getenv("OSA_DB_HOST","127.0.0.1"),
            port=int(os.getenv("OSA_DB_PORT",5432)),
            dbname=os.getenv("OSA_DB_NAME","osa_db"),
            user=os.getenv("OSA_DB_USER","postgres"),
            password=os.getenv("OSA_DB_PASS",""),
        )
        with conn.cursor() as cur:
            cur.execute("""
                SELECT classification FROM collect.reference_classifications
                WHERE source_code = 'SIPRI_LABELS'
                  AND country_iso3 IS NULL
            """)
            labels = {row[0].lower() for row in cur.fetchall()}
        conn.close()
        return labels
    except Exception:
        # Fallback local
        return {
            "africa", "north africa", "sub-saharan africa",
            "central africa", "east africa", "west africa",
            "southern africa", "middle east", "europe",'''

if OLD_REGION in content:
    content = content.replace(OLD_REGION, NEW_REGION, 1)
    # Fermer la fonction fallback après la liste
    content = content.replace(
        '"southern africa", "middle east", "europe",',
        '"southern africa", "middle east", "europe",\n        }\n\nSIPRI_REGION_LABELS = _load_sipri_region_labels()',
        1
    )
    SIPRI_CSV.write_text(content, encoding="utf-8")
    print("OK -- fetcher_sipri_csv.py migré")
else:
    print("WARN -- Pattern fetcher_sipri_csv non trouvé — migration manuelle requise")

# ── 3. Patch fetcher_sipri_milex.py ──────────────────────────────────────────

SIPRI_MILEX = Path("collectors/fetcher_sipri_milex.py")
content2 = SIPRI_MILEX.read_text(encoding="utf-8")

OLD_SUB = '''# Sous-regions a ignorer (pas des pays)
SUBREGIONS = {
    "Africa", "North Africa", "Sub-Saharan Africa", "sub-Saharan Africa",
    "Central Africa", "East Africa", "Southern Africa", "West Africa",
    "Europe", "Americas", "Asia & Oceania", "Middle East",
}'''

NEW_SUB = '''# Sous-regions a ignorer (pas des pays)
# Source : collect.reference_classifications (source_code='SIPRI_LABELS')
def _load_sipri_subregions() -> set:
    """Charge les sous-régions SIPRI depuis collect.reference_classifications."""
    try:
        import psycopg2, os
        from dotenv import load_dotenv
        load_dotenv()
        conn = psycopg2.connect(
            host=os.getenv("OSA_DB_HOST","127.0.0.1"),
            port=int(os.getenv("OSA_DB_PORT",5432)),
            dbname=os.getenv("OSA_DB_NAME","osa_db"),
            user=os.getenv("OSA_DB_USER","postgres"),
            password=os.getenv("OSA_DB_PASS",""),
        )
        with conn.cursor() as cur:
            cur.execute("""
                SELECT classification FROM collect.reference_classifications
                WHERE source_code = 'SIPRI_LABELS'
                  AND country_iso3 IS NULL
            """)
            labels = {row[0] for row in cur.fetchall()}
        conn.close()
        return labels
    except Exception:
        return {
            "Africa", "North Africa", "Sub-Saharan Africa", "sub-Saharan Africa",
            "Central Africa", "East Africa", "Southern Africa", "West Africa",
            "Europe", "Americas", "Asia & Oceania", "Middle East",
        }

SUBREGIONS = _load_sipri_subregions()'''

if OLD_SUB in content2:
    content2 = content2.replace(OLD_SUB, NEW_SUB, 1)
    SIPRI_MILEX.write_text(content2, encoding="utf-8")
    print("OK -- fetcher_sipri_milex.py migré")
else:
    print("WARN -- Pattern fetcher_sipri_milex non trouvé — migration manuelle requise")

print()
print("Migration SIPRI terminée.")
print("imputer_v3.py : region_code lu depuis rf.countries (SELECT) — déjà conforme.")
