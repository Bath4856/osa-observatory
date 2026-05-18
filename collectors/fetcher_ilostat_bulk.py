#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA / ISA
ILOSTAT Bulk Fetcher
Production-ready

Télécharge les datasets ILOSTAT bulk et les extrait automatiquement.
Conserve toujours le fichier source téléchargé.
"""

import os
import sys
import gzip
import shutil
import zipfile
from pathlib import Path

import requests


# ============================================================
# CONFIG
# ============================================================

BASE_URL = "https://rplumber.ilo.org/data/indicator?id={code}&format=.csv.gz"

DATASETS = [
    "SDG_0831_SEX_ECO_RT_A",
    "EMP_NIFL_SEX_ECO_NB_A",
    "EMP_NIFL_ECO_OCU_NB_A",
    "EMP_NIFL_SEX_ECO_EST_NB_A",
]

RAW_DIR = Path(r"H:\data\raw\ilo")

HEADERS = {
    "User-Agent": "Mozilla/5.0 (OSA Observatory ILOSTAT Collector)"
}

TIMEOUT = 180


# ============================================================
# HELPERS
# ============================================================

def ensure_dir(path: Path):
    path.mkdir(parents=True, exist_ok=True)


def download_file(url: str, target: Path):
    print(f"[DOWNLOAD] {url}")

    r = requests.get(
        url,
        headers=HEADERS,
        timeout=TIMEOUT,
        stream=True
    )

    r.raise_for_status()

    with open(target, "wb") as f:
        for chunk in r.iter_content(chunk_size=1024 * 1024):
            if chunk:
                f.write(chunk)

    print(f"[OK] Saved: {target}")


def extract_gz(gz_path: Path):
    output = gz_path.with_suffix("")  # remove .gz

    print(f"[EXTRACT GZ] {gz_path.name} -> {output.name}")

    with gzip.open(gz_path, "rb") as f_in:
        with open(output, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)

    print(f"[OK] Extracted: {output}")


def extract_zip(zip_path: Path):
    print(f"[EXTRACT ZIP] {zip_path.name}")

    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(zip_path.parent)

    print(f"[OK] Extracted ZIP to {zip_path.parent}")


def process_dataset(code: str):
    url = BASE_URL.format(code=code)

    filename = f"{code}.csv.gz"
    target = RAW_DIR / filename

    try:
        download_file(url, target)

        suffixes = target.suffixes

        if ".gz" in suffixes:
            extract_gz(target)

        elif ".zip" in suffixes:
            extract_zip(target)

        else:
            print(f"[INFO] No extraction needed: {target.name}")

    except Exception as e:
        print(f"[ERROR] {code}: {e}")


# ============================================================
# MAIN
# ============================================================

def main():
    print("=" * 60)
    print("OSA / ISA — ILOSTAT BUL