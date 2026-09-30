"""
Correctif ciblé — fetcher_eiti_csv.py
Remplace EITI_AFRICAN_MEMBERS (dictionnaire statut unique par pays,
faux sur 8 pays sur 33, découvert le 2026-09-29) par un historique réel
à périodes, incluant les interruptions documentées.

============================================================
MÉTHODE DE RECHERCHE ET NIVEAU DE CONFIANCE (à lire avant usage)
============================================================
Reconstruit le 2026-09-29 par recherche web sur pages officielles
eiti.org, rapports de validation, communiqués de presse, et Wikipedia
(liste des membres actuels). Chaque période porte un champ "confidence" :

  HIGH : date précise trouvée et sourcée (page pays eiti.org, rapport
         de validation officiel, communiqué de presse daté).
  LOW  : statut actuel (2026) confirmé sur 3 sources indépendantes
         (eiti.org/countries, api.eiti.org/countries, Wikipedia), mais
         AUCUNE date d'origine retrouvée malgré plusieurs recherches
         dédiées. Le statut est alors appliqué de façon PRUDENTE
         seulement à partir de l'année de recherche (2026), PAS
         rétroactivement sur 2010-2024 -- voir "Pays sans historique
         datable" plus bas. Appliquer un statut inconnu rétroactivement
         reproduirait exactement le défaut qu'on corrige.

DÉCOUVERTE IMPORTANTE : deux pays ont une vraie interruption documentée,
pas une simple date d'adhésion unique :
  - Niger : actif dès 2009 (bulletin EITI nov. 2009, "Niger civil
    society return to EITI" -- suggère même une period antérieure non
    datée), réadmis officiellement le 13 février 2020. Statut entre
    l'interruption et 2020 : INCONNU (pas de preuve trouvée).
  - Guinée : candidate le 27 sept. 2007, suspension volontaire du
    19 déc. 2009 au 1er mars 2011 (crise politique), reprise ensuite.

STATUTS ACTUELS (2026) « suspendu » / « sous surveillance renforcée »
SANS date de début retrouvée -- délibérément NON appliqués
rétroactivement dans l'historique 2010-2024 (Cameroun, RCA, São Tomé
suspendus ; Éthiopie, Madagascar, Tanzanie sous surveillance) : voir
CURRENT_STATUS_FLAGS_2026 en fin de fichier, à titre documentaire
seulement, non utilisé dans le calcul.

8 pays retirés du dictionnaire précédent (confirmés non-membres sur
3 sources indépendantes) : Algérie, Bénin, Égypte, Guinée-Bissau,
Kenya, Namibie (jamais membre, confirmé par article de presse de
février 2025), Rwanda, Zimbabwe.

3 pays ajoutés (membres réels absents du dictionnaire précédent) :
Malawi (2014), São Tomé (candidat 22 fév. 2008), Seychelles (membre
confirmé, date d'origine non retrouvée -- confidence LOW).

Sources détaillées et méthode complète de recherche :
/home/claude/osa-unesco-chantier/eiti_historique_recherche.md
(document de travail, pas sur le VPS -- résumé ci-dessus suffisant
pour comprendre et vérifier ce fichier).
============================================================

Application : ce fichier définit EITI_AFRICAN_HISTORY et une nouvelle
fonction status_at_year(iso3, year) -> (status, confidence), à utiliser
en remplacement de EITI_AFRICAN_MEMBERS et de la logique actuelle de
_generate_compliance_legacy() dans collectors/fetcher_eiti_csv.py.
"""

from __future__ import annotations

# ── Barème statut -> score (inchangé, repris de fetcher_eiti_csv.py) ────────
STATUS_TO_SCORE_COMPLIANCE = {
    "compliant":            85.0,
    "meaningful progress":  65.0,
    "candidate":            45.0,
    "suspended":            15.0,
    "delisted":              5.0,
    "non-member":            0.0,
}

STATUS_TO_MEMBER_FLAG = {
    "compliant": 1, "meaningful progress": 1, "candidate": 1,
    "suspended": 1, "delisted": 0, "non-member": 0,
}


# ── Historique réel par pays : liste de périodes successives ────────────────
# Chaque période : {"status": str, "from": int, "to": int|None, "confidence": "HIGH"|"LOW"}
# "to": None signifie "toujours en cours au moment de la recherche (2026)".
EITI_AFRICAN_HISTORY: dict[str, list[dict]] = {

    "AGO": [
        {"status": "candidate", "from": 2022, "to": None, "confidence": "HIGH"},
    ],
    "CMR": [
        {"status": "candidate", "from": 2007, "to": 2013, "confidence": "HIGH"},
        {"status": "compliant", "from": 2013, "to": None, "confidence": "HIGH"},
        # Statut actuel (2026) = suspendu ; date de suspension non
        # retrouvée -- NON appliquée retroactivement, voir
        # CURRENT_STATUS_FLAGS_2026.
    ],
    "GAB": [
        {"status": "candidate", "from": 2004, "to": None, "confidence": "HIGH"},
        # Devenu "candidate close to compliance" en oct. 2010, jamais
        # confirmé "compliant" par la suite dans nos recherches --
        # laisse en "candidate" faute de transition confirmée.
    ],
    "COD": [
        {"status": "candidate", "from": 2008, "to": 2013, "confidence": "HIGH"},
        # Suspendu ~2013 (article Reuters, date exacte non retrouvée)
        {"status": "compliant", "from": 2014, "to": None, "confidence": "HIGH"},
    ],
    "COG": [
        {"status": "candidate", "from": 2008, "to": None, "confidence": "HIGH"},
    ],
    "MDG": [
        {"status": "candidate", "from": 2008, "to": None, "confidence": "HIGH"},
        # Statut actuel (2026) = sous surveillance renforcée ; date de
        # debut non retrouvee -- NON appliquee retroactivement.
    ],
    "STP": [
        {"status": "candidate", "from": 2008, "to": None, "confidence": "HIGH"},
        # Statut actuel (2026) = suspendu ; date non retrouvee -- NON
        # appliquee retroactivement.
    ],
    "SLE": [
        {"status": "candidate", "from": 2008, "to": None, "confidence": "HIGH"},
    ],
    "CIV": [
        {"status": "candidate", "from": 2008, "to": None, "confidence": "HIGH"},
    ],
    "MLI": [
        {"status": "candidate", "from": 2007, "to": 2011, "confidence": "HIGH"},
        {"status": "compliant", "from": 2011, "to": None, "confidence": "HIGH"},
    ],
    "MRT": [
        {"status": "candidate", "from": 2005, "to": 2010, "confidence": "HIGH"},
        {"status": "compliant", "from": 2010, "to": None, "confidence": "HIGH"},
    ],
    "LBR": [
        {"status": "candidate", "from": 2007, "to": 2009, "confidence": "HIGH"},
        {"status": "compliant", "from": 2009, "to": None, "confidence": "HIGH"},
    ],
    "GHA": [
        {"status": "candidate", "from": 2003, "to": 2010, "confidence": "HIGH"},
        {"status": "compliant", "from": 2010, "to": None, "confidence": "HIGH"},
    ],
    "TGO": [
        {"status": "candidate", "from": 2010, "to": None, "confidence": "HIGH"},
    ],
    "UGA": [
        {"status": "candidate", "from": 2020, "to": None, "confidence": "HIGH"},
    ],
    "MWI": [
        {"status": "candidate", "from": 2014, "to": None, "confidence": "HIGH"},
    ],
    "SEN": [
        {"status": "candidate", "from": 2013, "to": 2018, "confidence": "HIGH"},
        {"status": "meaningful progress", "from": 2018, "to": None, "confidence": "HIGH"},
    ],

    # -- Pays avec interruption reelle documentee (pas une simple date) --
    "GIN": [
        {"status": "candidate", "from": 2007, "to": 2009, "confidence": "HIGH"},
        # Suspension volontaire du 19 dec. 2009 au 1er mars 2011
        {"status": "suspended", "from": 2009, "to": 2011, "confidence": "HIGH"},
        {"status": "candidate", "from": 2011, "to": None, "confidence": "HIGH"},
    ],
    "NER": [
        # Actif des 2009 au moins (bulletin EITI), statut precis
        # 2009-2019 non retrouve -- deux hypotheses non tranchees
        # (interruption non datee, ou continuite jamais formalisee
        # au niveau "implementing country" avant 2020). Confidence LOW
        # sur toute la periode anterieure a 2020.
        {"status": "candidate", "from": 2009, "to": 2020, "confidence": "LOW"},
        {"status": "candidate", "from": 2020, "to": None, "confidence": "HIGH"},
    ],

    # -- Pays confirmes membres, date d'origine NON retrouvee (confidence LOW) --
    # Statut actuel (2026) applique prudemment, PAS retroactivement sur
    # 2010-2024 sans justification -- voir status_at_year().
    "BFA": [{"status": "meaningful progress", "from": 2026, "to": None, "confidence": "LOW"}],
    "TCD": [{"status": "candidate", "from": 2026, "to": None, "confidence": "LOW"}],
    "MOZ": [{"status": "compliant", "from": 2026, "to": None, "confidence": "LOW"}],
    "NGA": [{"status": "compliant", "from": 2026, "to": None, "confidence": "LOW"}],
    "SYC": [{"status": "candidate", "from": 2026, "to": None, "confidence": "LOW"}],
    "ZMB": [{"status": "compliant", "from": 2026, "to": None, "confidence": "LOW"}],
    "CAF": [{"status": "suspended", "from": 2026, "to": None, "confidence": "LOW"}],
    "TZA": [{"status": "meaningful progress", "from": 2026, "to": None, "confidence": "LOW"}],
    "ETH": [{"status": "candidate", "from": 2026, "to": None, "confidence": "LOW"}],

    # -- 8 pays retires : confirmes non-membres sur 3 sources
    # independantes (eiti.org, api.eiti.org, Wikipedia, 2026-09-29).
    # Aucune entree -> non-member sur toute la periode (comportement
    # par defaut de status_at_year, voir plus bas). Liste explicite
    # pour la tracabilite :
    #   DZA, BEN, EGY, GNB, KEN, NAM, RWA, ZWE
}


def status_at_year(iso3: str, year: int) -> tuple[str, str]:
    """
    Retourne (status, confidence) pour un pays et une annee donnes.
    "non-member" / "HIGH" si le pays n'a aucune periode active cette
    annee-la (inclut les 8 pays retires et toute annee hors periode
    connue pour les autres).
    """
    periods = EITI_AFRICAN_HISTORY.get(iso3, [])
    for p in periods:
        end = p["to"] if p["to"] is not None else 9999
        if p["from"] <= year < end:
            return p["status"], p["confidence"]
    return "non-member", "HIGH"


# ── Statuts actuels (2026) non appliques retroactivement -- documentaire ────
# Ces indicateurs existent aujourd'hui mais leur date de debut n'a pas
# ete retrouvee ; ne PAS les injecter dans l'historique 2010-2024 sans
# une vraie date sourcee. A completer si une recherche future trouve
# la date exacte.
CURRENT_STATUS_FLAGS_2026 = {
    "CMR": "suspended (raison : engagement insuffisant des parties prenantes)",
    "CAF": "suspended (raison : engagement insuffisant des parties prenantes)",
    "STP": "suspended (raison non precisee sur la page officielle)",
    "ETH": "under enhanced scrutiny",
    "MDG": "under enhanced scrutiny",
    "TZA": "under enhanced scrutiny",
}
