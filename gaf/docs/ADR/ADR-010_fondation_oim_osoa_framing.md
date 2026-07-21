# ADR-010 — Cadre institutionnel Fondation BAKAÑ / OIM / OSOA

**Statut :** ACCEPTED
**Décidé le :** 20 juillet 2026
**Finding associé :** ADR010_FOUNDATION_OIM_OSOA_FRAMING_20260720

## Contexte

Un projet de statuts institutionnels de niveau fondateur (« Fondation BAKAÑ »,
inspiré des textes constitutifs du CERN, de la Fondation Wikimedia et de la
Fondation Linux) a été présenté en réunion, en amont de la mise en œuvre
opérationnelle d'OSOA. Ce document soulève quatre questions structurantes
pour l'architecture déjà construite (ADR-006/007/008 — diagnostic par
pilier, OIM, OSOA) qu'il convient de trancher et de tracer avant d'aller plus
loin dans la construction technique.

## Décisions actées

### 1. La Fondation comme personne morale signataire des contrats OSOA

La Fondation BAKAÑ sera créée en République du Cameroun avant le lancement
institutionnel de septembre 2027. C'est elle qui portera la capacité
juridique à signer les contrats issus de la filière OSOA (`osoa.contracts`).

**Conséquence directe sur le séquencement** : la construction et le test du
pipeline OSOA (API, portail, traitement documentaire) ne sont **pas**
bloqués par le calendrier de création de la Fondation — seule l'**exécution
réelle** d'un contrat (signature engageant une personne morale) l'est.
« Rendre utilisable OSOA », déjà identifié comme prochaine priorité
opérationnelle, peut donc avancer sans attendre la structure légale.

Le reste des préoccupations institutionnelles (statuts complets, gouvernance
en collèges, garanties d'indépendance) sera traité au cas par cas, avec pour
objectif que la structure soit prête à 90-100% du calendrier au lancement de
septembre 2027 — pas nécessairement dès aujourd'hui.

### 2. Taxonomie documentaire OSOA et traitement par IA documentaire

OSOA traite trois catégories de documents entrants, aux régimes distincts :

- **AMI / AO / AOI** (Avis de Manifestation d'Intérêt, Appel d'Offres, Appel
  d'Offres International) — ouverts, généralement portés par le
  Collège/Comité Technique.
- **DP** (Demande de Proposition) — réservée aux cabinets sollicitant un
  accompagnement, rattachée à `osoa.clients` (KYC propre, distinct de
  `mg.affiliates`).

Le traitement documentaire externe sera assuré par une IA documentaire,
utilisant les **mêmes outils d'analyse qu'OIM** — cohérent avec la doctrine
de capitalisation croisée déjà vérifiée en session (le chemin interne et le
chemin externe convergent vers le même patron d'intervention partagé,
`mg.intervention_patterns`).

**Réserve actée** : la valorisation de ce traitement documentaire comme
signal positif PNUM pour le pays hôte n'est recevable que si elle repose sur
des faits observables et mesurables (volume de documents traités, latence de
traitement, taux d'automatisation réel) — jamais sur une déclaration
d'intention. Cohérence stricte avec la doctrine P7E (aucun indicateur de
perception).

### 3. Cadre probabiliste des moteurs OSA — formalisation et limite

Cadre retenu, à des fins pédagogiques et de communication :

- **POA, AMAR, GENECO** (Produit 2, moniteurs sectoriels) **détectent** des
  signaux de dégradation — ils ne modifient jamais directement le calcul de
  l'ISA. Un signal non traité se traduira, s'il persiste, en dégradation
  observée des indicateurs réels lors d'un cycle de collecte futur, donc en
  probabilité décroissante de l'ISA à venir.
- **OIM et OSOA** (interventions, filières interne et externe respectivement)
  **recommandent** des actions — ils ne modifient jamais directement le
  calcul de l'ISA non plus. Seule une amélioration réellement collectée lors
  d'un cycle futur fait remonter l'ISA.

**Garde-fou acté, symétrique à celui déjà en place pour AMAR** (« outil
d'aide à l'analyse, ne remplace pas les évaluations des autorités
compétentes ») : toute surface publique (API, portail) exposant des sorties
OIM ou OSOA doit porter un disclaimer équivalent — une recommandation
d'intervention n'équivaut jamais à une amélioration actée. Nécessaire pour
préserver la neutralité scientifique, cœur de la Charte de Neutralité déjà
en vigueur.

### 4. Dénomination formelle — « Moteur de génie scientifique »

OIM et OSOA réunis sont désignés sous le nom de **Moteur de génie
scientifique** de l'OSA. Cette dénomination est fixée formellement par le
présent ADR pour prévenir toute dérive de nommage — le même défaut qu'a
connu la paire OSOA/OASA (jamais tranchée dans le document source d'origine,
cf. ADR-008) ne doit pas se reproduire.

## Conséquences

- Aucun changement de priorité opérationnelle : « rendre utilisable OSOA »
  (API + portail) reste la prochaine étape technique, non retardée par le
  calendrier de la Fondation.
- Le pipeline de traitement documentaire OSOA (AMI/AO/AOI/DP, IA
  documentaire) devient un sous-chantier explicite de « rendre utilisable
  OSOA », à cadrer techniquement lors de sa mise en œuvre.
- Un disclaimer standard pour toute sortie OIM/OSOA reste à rédiger et à
  intégrer lors de la construction des API/portail correspondantes — non
  fait à ce jour.
- Le projet de statuts complet (Titres I à XVI, Constitution doctrinale) est
  noté comme référence à moyen terme, non engagé formellement par le présent
  ADR — seul le rôle de signataire contractuel de la Fondation est acté ici.
