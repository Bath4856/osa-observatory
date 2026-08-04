# ADR-011 — Roadmap de maturation scientifique d'OIM (V1 à V6) et registre de maturité des briques

**Statut :** ACCEPTED
**Décidé le :** 4 août 2026

## Contexte

OIM V1 (génération automatique des 9 analyses primaires par pays+pilier,
puis synthèse INTERDEPENDANCE à partir des 9 promues) vient d'être construit
et validé en conditions réelles — 9/9 méthodes réussies sur données ISA
réelles (NAM/PTRA/2024), après correction d'un défaut de conception majeur :
le schéma JSON seul ne suffit pas à contraindre un LLM, il faut le
vocabulaire autorisé explicite en langage naturel en plus du schéma.

Théo a alors posé une question de fond : OIM n'est pas lui-même un moteur
scientifique — il **consomme** les résultats produits par ISA (et, à terme,
POA/GAP/référentiels/règles métier) pour le pilier étudié, puis les
transforme en connaissance de génie scientifique. Les 10 méthodes ne
devraient donc pas être alimentées uniquement par le score observé du
pilier, mais par l'ensemble du **patrimoine scientifique** disponible —
POA observés, GAP calculés (et leur coût du déficit quand calculable),
référentiels normatifs, règles métier, interdépendance.

Vérification faite avant toute décision : la plupart de ces briques
n'existent aujourd'hui que comme structure vide ou comme concept, pas comme
donnée réelle (cf. tableau ci-dessous). Construire OIM comme s'il pouvait
déjà s'appuyer sur ces briques aurait été une anticipation contraire à la
doctrine du projet (« jamais construire sur une donnée qui n'existe pas »).

## Décisions actées

### 1. Roadmap de maturation par versions successives

OIM se construit en versions successives, chacune ajoutant une seule brique
scientifique nouvellement mature — jamais plusieurs à la fois, jamais une
brique encore immature :

| Version | Entrée ajoutée | Objectif |
| --- | --- | --- |
| OIM V1 | Score du pilier (données ISA actuelles) | Valider le moteur — **fait, validé ce jour** |
| OIM V2 | Premiers POA | Dès que le référentiel POA a de vraies observations |
| OIM V3 | GAP | Passerelle entre POA et OIM — priorité haute une fois V2 en place |
| OIM V4 | Règles métier | Développées progressivement, méthode par méthode |
| OIM V5 | Référentiels normatifs | Travail doctrinal parallèle (ISO, FAO, UNODC, etc.) |
| OIM V6 | Interdépendance mature | Généralisation au-delà de la synthèse mono-pays déjà construite |

### 2. Registre officiel de maturité des briques scientifiques

Chaque brique porte un statut explicite, mis à jour à mesure de son
avancement réel — jamais supposé :

| Brique | Statut au 4 août 2026 |
| --- | --- |
| Scores des piliers (ISA) | ✅ Production |
| POA | 🟡 Construction (taxonomie `rf.poa_phenomenon_domain/type` créée, aucune observation réelle) |
| GAP | 🟡 Prototype (schéma `ma.poa_gap_observation` créé, table vide) |
| Référentiels métiers (règles) | 🔵 Conception (n'existe nulle part) |
| Référentiels normatifs (ISO, FAO, UNODC...) | 🔵 Conception (n'existe nulle part) |
| Interdépendance | 🟡 Expérimentation (synthèse mono-pays construite ce jour, jamais généralisée) |

### 3. Le "Scientific Snapshot" comme structure cible

À terme, chaque génération des 10 méthodes reposera sur un **snapshot
scientifique figé**, unique par pays+pilier+année, réunissant score du
pilier, POA, GAP, référentiels applicables, règles métier, coût du déficit
quand calculable, et interdépendance — plutôt que sur des appels dispersés.
Bénéfices actés : toutes les méthodes travaillent sur le même contexte,
l'audit devient trivial, la reproductibilité est garantie.

**Garde-fou impératif** : toute catégorie du snapshot non encore peuplée par
une vraie donnée doit apparaître explicitement comme `NON_DISPONIBLE` (ou
`NULL` documenté), **jamais silencieusement omise** — le LLM ne doit jamais
combler ce vide par une invention. Cohérent avec le garde-fou déjà acté pour
MULTICRITERE (restriction aux champs de score bornés `[0,1]` par
construction, jamais une pente ou un delta).

### 4. Distinction du coût du déficit — deux cas explicites

Quand OSA sait calculer un coût de déficit (ex. volume × valeur moyenne), le
moteur peut l'utiliser. Quand OSA ne sait pas calculer, le champ reste
`NON_DISPONIBLE` — jamais une estimation inventée par le LLM. Cohérent avec
la refonte de l'analyse économique du pilier (ce jour) en "Analyse
Économique Stratégique" 100% qualitative, sans aucun chiffre inventé.

## Conséquences

- OIM V1 est déclaré stable et clos ce jour — aucun développement
  scientifique supplémentaire n'est engagé tant que la brique suivante
  (POA, V2) n'a pas de vraie donnée observée.
- Le chantier POA déjà en cours (taxonomie 3 niveaux, session du 27 juillet)
  devient explicitement la prochaine priorité scientifique avant toute
  extension d'OIM.
- Le "Scientific Snapshot" n'est pas construit ce jour — seule son
  architecture cible est actée par le présent ADR, à implémenter
  progressivement au rythme de maturation des briques (V2 à V6).
- Cette stratégie de développement à faible risque permet de produire des
  livrables rapidement (OIM V1 opérationnel) tout en renforçant en continu
  leur qualité scientifique, sans jamais anticiper une donnée qui n'existe
  pas encore.
