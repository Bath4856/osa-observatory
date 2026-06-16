#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT P7I (EARLY WARNING COMPOSITE)

Corrections (AUDIT OSA-2026-001) :
- [P2] Ajout de missing_country_count et missing_countries dans le
  résultat lorsque len(countries) < 54. Améliore la traçabilité :
  le rapport indique combien et quels pays sont absents, plutôt qu'un
  WARNING opaque.
"""

import time
import requests

MODULE = "P7I"

# Liste de référence des 54 ISO3 africains
# Lue ici statiquement ; peut être remplacée par un appel à
# /api/v2/countries si disponible au moment de l'audit.
_AFRICA_ISO3 = {
    "AGO","BEN","BWA","BFA","BDI","CPV","CMR","CAF","TCD","COM",
    "COD","COG","CIV","DJI","EGY","GNQ","ERI","SWZ","ETH","GAB",
    "GMB","GHA","GIN","GNB","KEN","LSO","LBR","LBY","MDG","MWI",
    "MLI","MRT","MUS","MAR","MOZ","NAM","NER","NGA","RWA","STP",
    "SEN","SLE","SOM","ZAF","SSD","SDN","TZA","TGO","TUN","UGA",
    "ZMB","ZWE","DZA",
}


def run(cfg: dict) -> dict:

    start = time.time()
    base  = (cfg.get("api_url") or cfg.get("api_base_url", "")).rstrip("/")

    try:
        response = requests.get(
            f"{base}/api/v2/early-warning/composite",
            timeout=60,
        )

        elapsed_ms = round((time.time() - start) * 1000, 2)

        if response.status_code != 200:
            return {
                "module":      MODULE,
                "status":      "FAIL",
                "status_code": response.status_code,
                "elapsed_ms":  elapsed_ms,
            }

        rows = response.json()

        if not isinstance(rows, list):
            return {
                "module":    MODULE,
                "status":    "FAIL",
                "reason":    "INVALID_PAYLOAD",
                "elapsed_ms": elapsed_ms,
            }

        total_alerts       = len(rows)
        countries          = set()
        years              = set()
        confidence_values  = []
        score_values       = []
        low_confidence     = 0

        confidence_threshold = (
            cfg.get("minimum_confidence", {}).get("p7i", 0.50)
        )

        for row in rows:
            iso3       = row.get("country_iso3")
            year       = row.get("year")
            score      = row.get("amar_composite_score")
            confidence = row.get("amar_composite_confidence")

            if iso3: countries.add(iso3)
            if year is not None: years.add(year)

            try:
                if score is not None:
                    score_values.append(float(score))
                if confidence is not None:
                    c = float(confidence)
                    confidence_values.append(c)
                    if c < confidence_threshold:
                        low_confidence += 1
            except Exception:
                pass

        avg_confidence = (
            round(sum(confidence_values) / len(confidence_values), 4)
            if confidence_values else None
        )

        # Pays africains absents du résultat
        missing_countries     = sorted(_AFRICA_ISO3 - countries)
        missing_country_count = len(missing_countries)

        # ── Statut ────────────────────────────────────────────────
        status = "PASS"
        if total_alerts == 0:
            status = "FAIL"
        elif missing_country_count > 0:
            status = "WARNING"
        elif low_confidence > 0:
            status = "WARNING"

        return {
            "module":                MODULE,
            "status":                status,
            "elapsed_ms":            elapsed_ms,
            "total_alerts":          total_alerts,
            "countries":             len(countries),
            "missing_country_count": missing_country_count,
            "missing_countries":     missing_countries,
            "years":                 sorted(list(years)),
            "avg_confidence":        avg_confidence,
            "min_confidence":        min(confidence_values) if confidence_values else None,
            "max_confidence":        max(confidence_values) if confidence_values else None,
            "low_confidence":        low_confidence,
            "confidence_threshold":  confidence_threshold,
            "min_score":             min(score_values) if score_values else None,
            "max_score":             max(score_values) if score_values else None,
        }

    except Exception as e:
        return {
            "module": MODULE,
            "status": "FAIL",
            "error":  str(e),
        }


if __name__ == "__main__":
    import json
    print(json.dumps(run({
        "api_url": "https://api.osa-observatory.africa",
        "minimum_confidence": {"p7i": 0.50},
    }), indent=2))
