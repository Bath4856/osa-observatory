"""
OSA Observatory — fix_eiti_fetcher_reference_table.py
Sprint 9 — Chantier 9B extension — Mai 2026

Migre fetcher_eiti_csv.py pour lire les statuts EITI depuis
collect.reference_classifications au lieu de la liste en dur.

La fonction _generate_compliance_builtin est remplacée par
_generate_compliance_from_db qui lit la table de référence.
"""
from pathlib import Path

FETCHER = Path("collectors/fetcher_eiti_csv.py")
content = FETCHER.read_text(encoding="utf-8")

# ── Remplacer _generate_compliance_builtin ────────────────────────────────────

OLD_FUNC = '''    def _generate_compliance_builtin(
        self, metric: str, year_from: int, year_to: int
    ) -> list[DataRecord]:
        """Génère les scores depuis EITI_AFRICAN_MEMBERS pour toutes les années."""'''

NEW_FUNC = '''    def _generate_compliance_builtin(
        self, metric: str, year_from: int, year_to: int
    ) -> list[DataRecord]:
        """
        Charge les statuts EITI depuis collect.reference_classifications.
        Fallback sur EITI_AFRICAN_MEMBERS si la table est inaccessible.
        Doctrine OSA : pas de données de référence codées en dur.
        """
        try:
            return self._generate_compliance_from_db(metric, year_from, year_to)
        except Exception as e:
            self.log.warning(
                "collect.reference_classifications inaccessible (%s) "
                "— fallback sur données intégrées 2024", e
            )
            return self._generate_compliance_legacy(metric, year_from, year_to)

    def _generate_compliance_from_db(
        self, metric: str, year_from: int, year_to: int
    ) -> list[DataRecord]:
        """Lit les statuts EITI depuis collect.reference_classifications."""
        import psycopg2
        conn = self._get_db_conn()
        records: list[DataRecord] = []
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT country_iso3, classification, score_value,
                           valid_from, valid_to,
                           (metadata->>'since')::int AS since
                    FROM collect.reference_classifications
                    WHERE source_code = 'EITI'
                      AND country_iso3 IS NOT NULL
                    ORDER BY country_iso3, valid_from
                """)
                rows = cur.fetchall()
        finally:
            conn.close()

        # Construire un dict pays → liste de statuts historiques
        statuts: dict[str, list] = {}
        for iso3, classif, score, vfrom, vto, since in rows:
            if iso3 not in statuts:
                statuts[iso3] = []
            statuts[iso3].append({
                "status": classif, "score": score,
                "valid_from": vfrom, "valid_to": vto or 9999,
                "since": since or vfrom
            })

        for iso3, history in statuts.items():
            if iso3 not in AFRICAN_ISO3:
                continue
            for year in range(year_from, year_to + 1):
                # Trouver le statut valide pour cette année
                status = "non-member"
                for entry in sorted(history, key=lambda x: x["valid_from"]):
                    if year >= entry["since"] and year <= entry["valid_to"]:
                        status = entry["status"]
                        break
                value = self._status_to_metric(status, metric)
                records.append({"iso3": iso3, "year": year, "value": value})

        self.log.info(
            "Compliance depuis DB → %d enregistrements (%d pays)",
            len(records), len(statuts)
        )
        return records

    def _generate_compliance_legacy(
        self, metric: str, year_from: int, year_to: int
    ) -> list[DataRecord]:
        """Fallback legacy — utilise EITI_AFRICAN_MEMBERS codé en dur."""'''

if OLD_FUNC in content:
    content = content.replace(OLD_FUNC, NEW_FUNC, 1)
    FETCHER.write_text(content, encoding="utf-8")
    print("OK -- fetcher_eiti_csv.py migré vers collect.reference_classifications")
    print("   _generate_compliance_builtin → lit la table DB")
    print("   _generate_compliance_legacy  → fallback si DB inaccessible")
else:
    print("WARN -- pattern non trouvé")
    idx = content.find("_generate_compliance_builtin")
    print(f"  Ligne trouvée : {repr(content[idx:idx+100])}")
