#!/usr/bin/env python3
"""
Tests de collectors/country_resolver.py -- sans base de donnees.
Les lignes de rf.countries ci-dessous reprennent celles observees le 2026-09-28
(name_en et alias reels) ; name_fr et les pays sans alias sont a titre de test.

Lancer :  python collectors/test_country_resolver.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from country_resolver import CountryResolver, CoverageError  # noqa: E402

ROWS = [
    ("CIV", "Côte d'Ivoire", "Côte d'Ivoire", {"WB": "Cote d Ivoire", "ACLED": "Ivory Coast"}),
    ("COD", "DR Congo", "RD Congo", {"WB": "Congo, Dem. Rep.", "FAO": "249",
                                      "ACLED": "Democratic Republic of the Congo", "COMTRADE": "180"}),
    ("COG", "Congo", "Congo", {"WB": "Congo, Rep.", "ACLED": "Republic of the Congo"}),
    ("CPV", "Cabo Verde", "Cap-Vert", {"ALT": "Cape Verde", "ACLED": "Cape Verde"}),
    ("GMB", "Gambia", "Gambie", {"WB": "Gambia, The", "ACLED": "Gambia"}),
    ("STP", "São Tomé and Príncipe", "São Tomé-et-Príncipe", {}),
    ("SWZ", "Eswatini", "Eswatini", {"OLD_NAME": "Swaziland", "ACLED": "Eswatini"}),
    ("TZA", "Tanzania", "Tanzanie", {"ACLED": "Tanzania"}),
    ("MDG", "Madagascar", "Madagascar", {}),
    ("ZWE", "Zimbabwe", "Zimbabwe", {}),
    ("ETH", "Ethiopia", "Éthiopie", {}),
]
R = CountryResolver(ROWS)


def test_noms_acled_du_fichier_reel():
    cas = {"Ivory Coast": "CIV", "Democratic Republic of Congo": "COD",
           "Republic of Congo": "COG", "Cape Verde": "CPV", "Gambia": "GMB",
           "Sao Tome and Principe": "STP", "eSwatini": "SWZ", "Tanzania": "TZA"}
    for nom, iso3 in cas.items():
        assert R.resolve(nom)[0] == iso3, (nom, R.resolve(nom))


def test_noms_ucdp_avec_parentheses():
    cas = {"DR Congo (Zaire)": ("COD", "sans_parenthese"),
           "Kingdom of eSwatini (Swaziland)": ("SWZ", "dans_parenthese"),
           "Madagascar (Malagasy)": ("MDG", "sans_parenthese"),
           "Zimbabwe (Rhodesia)": ("ZWE", "sans_parenthese"),
           "Congo": ("COG", "exact")}
    for nom, attendu in cas.items():
        assert R.resolve(nom) == attendu, (nom, R.resolve(nom))


def test_pays_hors_referentiel_et_code_numerique():
    assert R.resolve("Afghanistan") == (None, "inconnu")
    assert R.resolve("249") == (None, "inconnu")          # code FAO ignore


def test_couverture_manquante_leve_une_erreur():
    try:
        R.resolve_all(["DR Congo (Zaire)"], expected={"COD", "ETH"}, label="test")
    except CoverageError as exc:
        assert "ETH" in str(exc)
        return
    raise AssertionError("CoverageError attendue")


def test_doublon_de_pays_leve_une_erreur():
    try:
        R.resolve_all(["Republic of Congo", "Congo (Kinshasa)"], label="test")
    except ValueError:
        return
    raise AssertionError("ValueError attendue (deux noms -> COG)")


def test_cle_ambigue_non_resolue():
    r = CountryResolver([("AAA", "Alpha", None, {"X": "Same"}), ("BBB", "Beta", None, {"X": "Same"})])
    assert r.resolve("Same") == (None, "ambigu")


def test_alias_region_ignore():
    # Constate en base le 2026-09-29 : EGY et LBY partagent tous deux
    # aliases->'SIPRI_REGION' = 'Middle East' -- une region, pas un nom de
    # pays. Ne doit ni creer d'ambiguite ni etre resolu comme un pays.
    r = CountryResolver([
        ("EGY", "Egypt", None, {"SIPRI_REGION": "Middle East"}),
        ("LBY", "Libya", None, {"SIPRI_REGION": "Middle East"}),
    ])
    assert r.resolve("Middle East") == (None, "inconnu")
    assert r.resolve("Egypt") == ("EGY", "exact")
    assert r.resolve("Libya") == ("LBY", "exact")


def test_tous_les_pays_attendus_retrouves():
    noms = ["Ivory Coast", "Democratic Republic of Congo", "Republic of Congo", "Cape Verde",
            "Gambia", "Sao Tome and Principe", "eSwatini", "Tanzania", "Madagascar", "Zimbabwe", "Ethiopia"]
    m = R.resolve_all(noms, expected={r[0] for r in ROWS}, label="test")
    assert len(m) == len(ROWS)


if __name__ == "__main__":
    tests = [(k, v) for k, v in sorted(globals().items()) if k.startswith("test_")]
    for nom, fn in tests:
        fn()
        print("OK  ", nom)
    print(f"\n{len(tests)} tests passes")
