#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OSA ISA – Sprint 24 GAF v3
Tests unitaires : orientation_engine.py + finding_hash

Nouveautés v3 :
- Vérification publication_impact dans chaque règle
- Vérification iprs_weight
- Test compute_finding_hash (récurrence)
"""

import sys
import hashlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

# Import adaptatif : gaf en local, gaf en production
import importlib, sys as _sys
_parent = str(Path(__file__).resolve().parents[1])
if _parent not in _sys.path:
    _sys.path.insert(0, str(Path(__file__).resolve().parents[1].parent))
from gaf.core.orientation_engine import OrientationEngine
from gaf.core.gaf_ledger import compute_finding_hash

engine = OrientationEngine()


def assert_finding(module, finding_text, expected_code, expected_severity,
                   expected_impact=None, expected_iprs=None):
    result = engine.classify_finding(module, finding_text)
    assert result["finding_code"] == expected_code, (
        f"[{module}] Code attendu={expected_code}, obtenu={result['finding_code']}")
    assert result["severity"] == expected_severity, (
        f"[{module}] Sévérité attendue={expected_severity}, obtenu={result['severity']}")
    if expected_impact:
        assert result.get("publication_impact") == expected_impact, (
            f"[{module}] Impact attendu={expected_impact}, obtenu={result.get('publication_impact')}")
    if expected_iprs is not None:
        assert result.get("iprs_weight") == expected_iprs, (
            f"[{module}] iprs_weight attendu={expected_iprs}, obtenu={result.get('iprs_weight')}")
    return result


# ── Tests règles ───────────────────────────────────────────────────────────

def test_r01_method_version_null():
    r = assert_finding("METHODOLOGY",
        "L3: 997865/998675 lignes (99.92%) avec method_version_id IS NULL",
        "METHOD_VERSION_ID_NULL", "CRITICAL", "BLOCKING", 5.00)
    assert r["owner"] == "DATA_STEWARD"
    print("✓ R01 METHOD_VERSION_NULL — BLOCKING 5.0 pts")


def test_r02_duplicate_values():
    r = assert_finding("METHODOLOGY",
        "5 (indicator_code, layer_id) avec doublons — 120 lignes excedentaires",
        "DUPLICATE_INDICATOR_VALUES", "CRITICAL", "BLOCKING", 5.00)
    assert r["owner"] == "DATA_STEWARD"
    print("✓ R02 DUPLICATE_VALUES — BLOCKING 5.0 pts")


def test_r03_weight_consistency():
    r = assert_finding("METHODOLOGY",
        "SOV_PECO/2024 weight sum=0.93750000",
        "WEIGHT_SUM_INCONSISTENT", "HIGH", "CONDITIONAL", 3.00)
    assert r["owner"] == "METHODOLOGY_COMMITTEE"
    print("✓ R03 WEIGHT_CONSISTENCY — CONDITIONAL 3.0 pts")


def test_r04_indicator_not_linked():
    r = assert_finding("METHODOLOGY",
        "PECO: ECO_LOG not linked and not excluded",
        "INDICATOR_UNLINKED", "HIGH", "CONDITIONAL", 2.00)
    assert "ECO_LOG" in (r["object_code"] or "")
    print("✓ R04 INDICATOR_NOT_LINKED — CONDITIONAL 2.0 pts")


def test_r05_endpoint_missing():
    r = assert_finding("API_CONTRACT_ADVANCED",
        "{'endpoint': '/api/v2/early-warning/conflict-economy', 'status': 404}",
        "API_ENDPOINT_MISSING", "HIGH", "CONDITIONAL", 2.00)
    print("✓ R05 ENDPOINT_MISSING — CONDITIONAL 2.0 pts")


def test_r06_endpoint_timeout():
    r = assert_finding("API_CONTRACT_ADVANCED",
        "TIMEOUT: /api/v2/early-warning/conflict-economy",
        "API_ENDPOINT_TIMEOUT", "MEDIUM", "NONE", 1.00)
    print("✓ R06 ENDPOINT_TIMEOUT — NONE 1.0 pt")


def test_r07_endpoint_slow():
    r = assert_finding("API_PERFORMANCE_ADVANCED",
        "{'endpoint': '/api/v2/sovereignty/swot', 'elapsed_ms': 9444.22, 'severity': 'MEDIUM'}",
        "API_ENDPOINT_SLOW", "MEDIUM", "NONE", 0.50)
    print("✓ R07 ENDPOINT_SLOW — NONE 0.5 pt")


def test_r08_null_values():
    r = assert_finding("DATA_QUALITY", "NULL_VALUES",
        "DATA_NULL_VALUES", "MEDIUM", "NONE", 1.00)
    print("✓ R08 NULL_VALUES — NONE 1.0 pt")


def test_r09_trajectory_inactive():
    r = assert_finding("TRAJECTORY",
        "inactive: ['PMIN_SMUGGLING_SIGNAL_RANK']",
        "TRAJECTORY_INDICATOR_INACTIVE", "MEDIUM", "NONE", 0.50)
    print("✓ R09 TRAJECTORY_INACTIVE — NONE 0.5 pt")


def test_r10_security_sensitive():
    r = assert_finding("SECURITY",
        "{'file': 'api/.env', 'pattern': 'password'}",
        "SECURITY_SENSITIVE_PATTERN", "LOW", "NONE", 0.25)
    print("✓ R10 SECURITY_SENSITIVE — NONE 0.25 pt")


def test_r11_missing_country():
    r = assert_finding("P7I",
        "missing_countries: ['LCA']",
        "COVERAGE_MISSING_COUNTRY", "LOW", "NONE", 0.25)
    print("✓ R11 MISSING_COUNTRY — NONE 0.25 pt")


def test_r12_no_auth_token():
    r = assert_finding("API_PERMISSIONS",
        "Passe B ignorée : aucun api_key ni auth_token dans cfg",
        "AUTH_TOKEN_NOT_CONFIGURED", "INFO", "NONE", 0.00)
    print("✓ R12 NO_AUTH_TOKEN — NONE 0.0 pt")


def test_unclassified():
    r = engine.classify_finding("DNS", "Quelque chose d'inattendu")
    assert r["finding_code"] == "UNCLASSIFIED"
    assert r["severity"] == "INFO"
    assert r.get("publication_impact") in ("NONE", None)
    print("✓ UNCLASSIFIED — NONE 0.0 pt")


# ── Tests finding_hash (récurrence) ────────────────────────────────────────

def test_finding_hash_deterministic():
    """Le même finding produit toujours le même hash."""
    h1 = compute_finding_hash("METHODOLOGY", "METHOD_VERSION_ID_NULL", "ma.indicator_values")
    h2 = compute_finding_hash("METHODOLOGY", "METHOD_VERSION_ID_NULL", "ma.indicator_values")
    assert h1 == h2, "Hash non déterministe"
    assert len(h1) == 64, "Hash SHA-256 doit faire 64 chars"
    print(f"✓ finding_hash déterministe : {h1[:16]}...")


def test_finding_hash_distinct():
    """Deux findings différents produisent des hashs différents."""
    h1 = compute_finding_hash("METHODOLOGY", "METHOD_VERSION_ID_NULL", "ma.indicator_values")
    h2 = compute_finding_hash("METHODOLOGY", "WEIGHT_SUM_INCONSISTENT", "ma.indicator_meta_links")
    h3 = compute_finding_hash("DATA_QUALITY", "METHOD_VERSION_ID_NULL", "ma.indicator_values")
    assert h1 != h2, "Codes différents → hashs différents"
    assert h1 != h3, "Modules différents → hashs différents"
    print("✓ finding_hash distinct par (module, finding_code, object_code)")


def test_finding_hash_none_object():
    """object_code=None est géré proprement."""
    h = compute_finding_hash("TRAJECTORY", "TRAJECTORY_INDICATOR_INACTIVE", None)
    assert len(h) == 64
    print("✓ finding_hash avec object_code=None")


# ── Test end-to-end ────────────────────────────────────────────────────────

def test_orient_run_full():
    sample_results = [
        {"module": "METHODOLOGY", "status": "FAIL", "findings": [
            "L3: 997865/998675 lignes (99.92%) avec method_version_id IS NULL",
            "SOV_PECO/2024 weight sum=0.93750000",
            "PECO: ECO_LOG not linked and not excluded",
        ]},
        {"module": "API_CONTRACT_ADVANCED", "status": "WARNING",
         "warnings": ["TIMEOUT: /api/v2/early-warning/conflict-economy"]},
        {"module": "DATA_QUALITY", "status": "WARNING", "warnings": ["NULL_VALUES"]},
        {"module": "DNS", "status": "PASS"},
    ]

    result = engine.orient_run(sample_results)

    assert result["total_findings"] == 5
    assert result["by_severity"]["CRITICAL"] == 1
    assert result["by_severity"]["HIGH"] == 2
    assert result["by_severity"]["MEDIUM"] == 2
    assert "DNS" not in result["by_module"]

    # Vérifier publication_impact présent dans tous les findings
    for f in result["findings"]:
        assert "publication_impact" in f, f"publication_impact absent : {f['finding_code']}"
        assert "iprs_weight" in f, f"iprs_weight absent : {f['finding_code']}"

    # Vérifier BLOCKING bien présent pour METHOD_VERSION_ID_NULL
    blocking = [f for f in result["findings"] if f["publication_impact"] == "BLOCKING"]
    assert len(blocking) == 1
    assert blocking[0]["finding_code"] == "METHOD_VERSION_ID_NULL"

    print(f"✓ orient_run_full — {result['total_findings']} findings | "
          f"BLOCKING={len(blocking)} | "
          f"iprs_total={sum(f['iprs_weight'] for f in result['findings']):.2f} pts")


if __name__ == "__main__":
    tests = [
        test_r01_method_version_null, test_r02_duplicate_values,
        test_r03_weight_consistency,  test_r04_indicator_not_linked,
        test_r05_endpoint_missing,    test_r06_endpoint_timeout,
        test_r07_endpoint_slow,       test_r08_null_values,
        test_r09_trajectory_inactive, test_r10_security_sensitive,
        test_r11_missing_country,     test_r12_no_auth_token,
        test_unclassified,
        test_finding_hash_deterministic, test_finding_hash_distinct,
        test_finding_hash_none_object,
        test_orient_run_full,
    ]

    passed = failed = 0
    print("═" * 55)
    print("  OSA GAF v3 – Tests orientation + finding_hash")
    print("═" * 55)

    for test in tests:
        try:
            test()
            passed += 1
        except (AssertionError, Exception) as e:
            print(f"✗ {test.__name__} — {e}")
            failed += 1

    print("═" * 55)
    print(f"  {passed}/{passed+failed} tests passés")
    print("═" * 55)
    if failed:
        sys.exit(1)
