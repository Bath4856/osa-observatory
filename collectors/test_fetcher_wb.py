"""
============================================================
OSA / ISA OBSERVATORY
test_fetcher_wb.py — Tests unitaires du fetcher World Bank
============================================================
Usage : python test_fetcher_wb.py
Pas de dépendance à la base de données — tests API uniquement
============================================================
"""

import sys
import time
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("test_wb")


def test_api_reachable() -> bool:
    """Vérifie que l'API World Bank est accessible."""
    try:
        import requests
        resp = requests.get(
            "https://api.worldbank.org/v2/country/ZAF/indicator/NY.GDP.PCAP.KD"
            "?format=json&per_page=1",
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        assert isinstance(data, list) and len(data) == 2
        log.info("API WB accessible — OK")
        return True
    except Exception as exc:
        log.error("API WB inaccessible : %s", exc)
        return False


def test_single_indicator_fetch() -> bool:
    """Teste la collecte réelle d'un indicateur sur 5 pays."""
    try:
        from fetcher_wb import fetch_wb_indicator
        from wb_indicator_map import AFRICAN_COUNTRIES_ISO3

        # Test sur ECO_GDP (indicateur stable et bien couvert)
        records = fetch_wb_indicator("NY.GDP.PCAP.KD", 2020, 2022)

        assert len(records) > 0, "Aucun enregistrement retourné"

        # Vérification structure
        for r in records[:3]:
            assert "iso3"  in r
            assert "year"  in r
            assert "value" in r
            assert r["iso3"] in AFRICAN_COUNTRIES_ISO3

        countries = {r["iso3"] for r in records if r["value"] is not None}
        log.info("ECO_GDP (2020-2022) : %d enregistrements, %d pays avec valeurs",
                 len(records), len(countries))
        assert len(countries) >= 10, f"Trop peu de pays : {len(countries)}"
        log.info("Test fetch indicateur — OK")
        return True
    except Exception as exc:
        log.error("Test fetch échoué : %s", exc)
        return False


def test_multiplier_application() -> bool:
    """Vérifie que le multiplicateur est appliqué correctement."""
    try:
        from wb_indicator_map import WB_INDICATOR_MAP

        # ECO_LOG a multiplier=20 (LPI sur 5 → ramené à 100)
        mapping = WB_INDICATOR_MAP["ECO_LOG"]
        assert mapping["multiplier"] == 20.0, "Multiplicateur ECO_LOG incorrect"

        # HUM_INF a multiplier=0.1 (pour 1000 → %)
        mapping = WB_INDICATOR_MAP["HUM_INF"]
        assert mapping["multiplier"] == 0.1, "Multiplicateur HUM_INF incorrect"

        log.info("Test multiplicateurs — OK")
        return True
    except Exception as exc:
        log.error("Test multiplicateurs échoué : %s", exc)
        return False


def test_country_list() -> bool:
    """Vérifie que la liste de pays est complète."""
    try:
        from wb_indicator_map import AFRICAN_COUNTRIES_ISO3, ISO3_TO_ISO2

        assert len(AFRICAN_COUNTRIES_ISO3) == 54, \
            f"Attendu 54 pays, trouvé {len(AFRICAN_COUNTRIES_ISO3)}"

        # Vérifier que tous les ISO3 ont un ISO2 correspondant
        for iso3 in AFRICAN_COUNTRIES_ISO3:
            assert iso3 in ISO3_TO_ISO2, f"ISO2 manquant pour {iso3}"
            assert len(iso3) == 3, f"Code ISO3 invalide : {iso3}"

        log.info("Test liste pays (54 pays africains) — OK")
        return True
    except Exception as exc:
        log.error("Test pays échoué : %s", exc)
        return False


def test_mapping_integrity() -> bool:
    """Vérifie l'intégrité du mapping indicateurs."""
    try:
        from wb_indicator_map import WB_INDICATOR_MAP

        required_fields = ["wb_code", "name_fr", "unit_code", "direction", "multiplier"]
        valid_directions = {"+", "-"}
        valid_units = {
            "PERCENT", "USD", "USD_CONST", "USD_PC", "TONNES",
            "PERSONS", "NB", "INDEX", "SCORE", "SCORE_0_100",
            "SCORE_0_10", "SCORE_0_1", "YEARS", "RATIO",
        }

        errors = []
        for osa_code, mapping in WB_INDICATOR_MAP.items():
            for field in required_fields:
                if field not in mapping:
                    errors.append(f"{osa_code} : champ manquant '{field}'")

            if mapping.get("direction") not in valid_directions:
                errors.append(f"{osa_code} : direction invalide '{mapping.get('direction')}'")

            if mapping.get("unit_code") not in valid_units:
                errors.append(f"{osa_code} : unit_code inconnu '{mapping.get('unit_code')}'")

            if not isinstance(mapping.get("multiplier"), (int, float)):
                errors.append(f"{osa_code} : multiplicateur invalide")

        if errors:
            for e in errors:
                log.error("  %s", e)
            return False

        log.info("Test intégrité mapping (%d indicateurs) — OK",
                 len(WB_INDICATOR_MAP))
        return True
    except Exception as exc:
        log.error("Test mapping échoué : %s", exc)
        return False


def run_all_tests() -> None:
    tests = [
        ("Intégrité du mapping",     test_mapping_integrity),
        ("Liste des pays (54)",      test_country_list),
        ("Multiplicateurs",          test_multiplier_application),
        ("Accessibilité API WB",     test_api_reachable),
        ("Fetch indicateur réel",    test_single_indicator_fetch),
    ]

    passed = 0
    failed = 0

    log.info("=" * 55)
    log.info("OSA Fetcher WB — suite de tests")
    log.info("=" * 55)

    for name, fn in tests:
        log.info("▶ %s", name)
        try:
            ok = fn()
        except Exception as exc:
            log.error("Erreur inattendue : %s", exc)
            ok = False

        if ok:
            passed += 1
        else:
            failed += 1
        time.sleep(0.3)

    log.info("=" * 55)
    log.info("Résultats : %d/%d tests passés", passed, passed + failed)
    log.info("=" * 55)

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    run_all_tests()
