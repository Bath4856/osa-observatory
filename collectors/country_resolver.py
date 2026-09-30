#!/usr/bin/env python3
"""
OSA Observatory -- collectors/country_resolver.py

Resolution commune des noms de pays vers ISO3, pour tous les collecteurs.

Pourquoi (constat du 2026-09-28) : deux collecteurs perdaient des pays en
silence, parce que le nom fourni par la source differait d'une lettre ou
d'une mention entre parentheses du nom attendu par un dictionnaire code en dur.
  ACLED : "Democratic Republic of Congo", "Republic of Congo", "eSwatini"
          (attendus : "...of the Congo", "Congo", "Eswatini") -> RDC, Congo et
          eSwatini absents de GEO_CON, GEO_TER, MIL_TER, PGEO_CIV.
  UCDP  : "DR Congo (Zaire)", "Kingdom of eSwatini (Swaziland)",
          "Madagascar (Malagasy)", "Zimbabwe (Rhodesia)" -> 4 pays absents de
          PGEO_EVT et des 8 autres indicateurs UCDP.
Dans les deux cas la ligne `df[df["iso3"].notna()]` ecartait ces pays sans
aucun message.

Principes :
  1. Les noms viennent de rf.countries (name_en, name_fr, valeurs textuelles
     de `aliases`) : pas de dictionnaire a maintenir dans chaque collecteur.
  2. Comparaison normalisee : sans accents, sans casse, sans ponctuation, sans
     le mot "the". Les codes numeriques d'alias (FAO, COMTRADE) sont ignores.
  3. Mentions entre parentheses : on essaie d'abord le nom complet, puis le nom
     sans parenthese, puis le contenu de la parenthese. Toute correspondance
     qui n'est pas exacte est signalee (WARNING), jamais silencieuse.
  4. Une cle ambigue (deux pays possibles) ne se resout pas : on ne devine pas.
  5. Deux noms differents de la source qui aboutissent au meme pays provoquent
     une erreur (risque de double comptage ou de faux rapprochement).
  6. `expected` : si un pays attendu n'est retrouve sous aucun nom, on leve
     CoverageError avec la liste. Plus jamais de pays perdu en silence.

Limite connue : le repli "sans parenthese" peut rapprocher a tort un nom du type
"Congo (Kinshasa)" du pays "Congo". La detection des doublons (point 5) et le
controle de couverture (point 6) sont la pour l'attraper.
"""

import logging
import re
import unicodedata
from typing import Iterable, Optional

log = logging.getLogger("country_resolver")


class CoverageError(RuntimeError):
    """Un pays attendu n'a ete retrouve sous aucun nom dans la source."""


def normalize(name: str) -> str:
    """Sans accents, sans casse, sans ponctuation, sans le mot 'the'."""
    s = unicodedata.normalize("NFKD", str(name)).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-z0-9 ]", " ", s.casefold())
    s = re.sub(r"\bthe\b", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def _levels(name: str) -> list:
    """Cles candidates (mode, cle), de la plus stricte a la plus souple."""
    exact = normalize(name)
    levels = [("exact", exact)]
    sans = normalize(re.sub(r"\([^)]*\)", " ", name))
    if sans and sans != exact:
        levels.append(("sans_parenthese", sans))
    for inside in re.findall(r"\(([^)]*)\)", name):
        key = normalize(inside)
        if key:
            levels.append(("dans_parenthese", key))
    return [(mode, key) for mode, key in levels if key]


class CountryResolver:
    """rows : iterable de (iso3, name_en, name_fr, aliases_dict)."""

    def __init__(self, rows: Iterable):
        self._index = {}
        self._names = {}
        for iso3, name_en, name_fr, aliases in rows:
            self._names[iso3] = name_en or iso3
            candidates = [name_en, name_fr]
            if isinstance(aliases, dict):
                # Seules les cles se terminant par un fournisseur reconnu
                # designent un nom de pays pour ce fournisseur. D'autres cles
                # portent une donnee annexe sur le meme pays (ex. SIPRI_REGION
                # : "Middle East" pour EGY et LBY, une region, pas un nom de
                # pays -- constate en base le 2026-09-29). Une valeur partagee
                # par plusieurs pays est de toute facon rejetee comme ambigue,
                # mais on evite de la faire remonter comme avertissement pour
                # un cas qui n'est pas une erreur de saisie.
                candidates += [
                    v for k, v in aliases.items()
                    if isinstance(v, str) and not v.strip().isdigit()
                    and not k.upper().endswith("_REGION")
                ]
            for cand in candidates:
                if not cand:
                    continue
                for _mode, key in _levels(cand)[:2]:   # exact + sans parenthese
                    self._index.setdefault(key, set()).add(iso3)
        ambiguous = {k: sorted(v) for k, v in self._index.items() if len(v) > 1}
        if ambiguous:
            log.warning("Cles de noms ambigues dans rf.countries (non resolues) : %s", ambiguous)

    @classmethod
    def from_db(cls, conn, active_only: bool = True) -> "CountryResolver":
        sql = "SELECT iso3, name_en, name_fr, aliases FROM rf.countries"
        if active_only:
            sql += " WHERE is_active"
        with conn.cursor() as cur:
            cur.execute(sql)
            return cls(cur.fetchall())

    @staticmethod
    def expected_from_db(conn) -> set:
        with conn.cursor() as cur:
            cur.execute("SELECT iso3 FROM rf.countries WHERE is_active")
            return {r[0] for r in cur.fetchall()}

    def name_of(self, iso3: str) -> str:
        return self._names.get(iso3, iso3)

    def resolve(self, name: str) -> tuple:
        """Retourne (iso3 ou None, mode) ; mode dans exact, sans_parenthese,
        dans_parenthese, ambigu, inconnu."""
        for mode, key in _levels(name):
            hit = self._index.get(key)
            if not hit:
                continue
            if len(hit) == 1:
                return next(iter(hit)), mode
            return None, "ambigu"
        return None, "inconnu"

    def resolve_all(self, names: Iterable, expected: Optional[Iterable] = None,
                    allow_duplicates: bool = False, label: str = "") -> dict:
        """Retourne {nom_source: iso3}. Leve ValueError sur doublon et
        CoverageError si un pays de `expected` n'est retrouve sous aucun nom."""
        mapping, approx, ambiguous, unknown = {}, {}, [], []
        for name in dict.fromkeys(names):
            iso3, mode = self.resolve(name)
            if iso3 is None:
                (ambiguous if mode == "ambigu" else unknown).append(name)
                continue
            mapping[name] = iso3
            if mode != "exact":
                approx[name] = (iso3, mode)

        by_iso = {}
        for name, iso3 in mapping.items():
            by_iso.setdefault(iso3, []).append(name)
        dups = {iso3: ns for iso3, ns in by_iso.items() if len(ns) > 1}
        if dups and not allow_duplicates:
            raise ValueError(f"[{label}] plusieurs noms de la source aboutissent au meme pays : {dups}")

        if approx:
            log.warning("[%s] correspondances NON exactes (a verifier) : %s", label, approx)
        if ambiguous:
            log.warning("[%s] noms ambigus, non resolus : %s", label, ambiguous)
        log.info("[%s] %d noms resolus, %d hors referentiel OSA", label, len(mapping), len(unknown))

        if expected is not None:
            missing = sorted(set(expected) - set(mapping.values()))
            if missing:
                detail = ", ".join(f"{i} ({self.name_of(i)})" for i in missing)
                raise CoverageError(f"[{label}] pays attendus introuvables dans la source : {detail}")
        return mapping
