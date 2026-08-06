# ADR-012 — Doctrine consolidée du moteur OIM (V1, arrêtée le 6 août 2026)

| Champ | Valeur |
|---|---|
| **Code** | `ADR-012_doctrine_consolidee_oim` |
| **Statut** | ACCEPTED |
| **Remplace en détail** | `ADR-OSA-OIM-001_final` (14 juillet 2026) — aligné en esprit, voir §11 |
| **Consolide** | ADR-010 (fondation OIM/OSOA), ADR-011 (roadmap V1-V6), et l'ensemble des décisions prises en session les 4, 5 et 6 août 2026 |
| **Organe de gouvernance** | Conseil technique OSA — ne touche à aucune ligne du Volume 0 |
| **Déclencheur** | Demande de Théo (6 août 2026) : rassembler toutes les doctrines OIM en un seul document avant de poursuivre |

## Contexte

OIM V1 a été construit et testé de bout en bout entre le 4 et le 6 août 2026, à travers plusieurs sessions et de nombreuses corrections successives. Plusieurs décisions doctrinales ont été prises au fil de l'eau, dans des échanges séparés, jamais consolidées. En reprenant l'ADR de juillet (`ADR-OSA-OIM-001_final`) pour ce travail de consolidation, un écart réel avec l'architecture effectivement construite a été identifié — traité au §11.

## 1. Deux chaînes, deux registres, jamais mélangés (inchangé depuis juillet)

```
                              OSA
                               │
                ┌──────────────┴──────────────┐
                │                              │
       Chaîne scientifique              Chaîne d'ingénierie
     (observation, qualification)         (architecture d'intervention)
                │                              │
              ISA                             OIM
              POA
            GENECO
              AMAR
```

La chaîne scientifique observe et qualifie ; elle ne bascule jamais dans la prescription. OIM ne devient jamais lui-même un objet doctrinal du Volume 0, ne requiert pas le Conseil scientifique panafricain.

## 2. La chaîne réellement construite et validée

```
Patrimoine scientifique (ISA + POA)
   ↓
9 analyses primaires (5W1H, SWOT, ZACHMAN, RISQUE, Analyse Économique
   Stratégique, GOUVERNANCE, MULTICRITERE, 5 Pourquoi)  -- voir §4 pour
   FAISABILITE, retiree de cette liste
   ↓
Cause racine (5 Pourquoi)
   ↓
Levier stratégique                    ← POINT D'ENTREE UNIQUE (§3)
   ↓
   ├── Interdépendance des leviers (niveau Vision, avant tout projet)
   ├── Étude d'opportunité (résumé public, exige le levier promu)
   ├── Schéma directeur (assemblage déterministe, aucun appel IA)
   └── Plan d'action = FAMILLE de projets/actions candidats (§4),
       chacun individuellement validé et promu
          ↓
       Interdépendance des interventions (niveau Plan d'action,
       sur un projet réel nommé)
```

Chaque flèche de cette chaîne a été testée en conditions réelles sur au moins deux visions indépendantes (NAM/PTRA/2024, CMR/PMIN/2024) avant d'être actée ici.

## 3. Le levier stratégique, point d'entrée unique (pivot)

Décision du 5 août 2026 : pour éviter une multitude de points d'entrée et les incohérences que cela produirait, **tout générateur IA en aval de la cause racine exige un levier `PROMOTED`** avant de s'exécuter — l'Étude d'opportunité, le Plan d'action, et les deux niveaux d'interdépendance en dépendent tous explicitement (garde-fou 422 sinon).

**Séparation référentiel / occurrence** (décision du 6 août 2026, cohérente avec toute l'architecture `rf`/`mg` du projet) :
- `rf.strategic_levers` — référentiel normatif (définition, nom, description, domaine, famille, statut d'approbation). Catalogue partagé entre toutes les visions, jamais écrit directement par l'IA.
- `mg.lever_evidence` — occurrence produite par le moteur (quelle analyse justifie quel levier, avec quel poids de pertinence, quelle méthode source).

L'IA ne peut que **proposer** (`mg.strategic_lever_proposals`, AI_DRAFTED→HUMAN_VALIDATED→PROMOTED) — jamais écrire directement dans le catalogue partagé.

## 4. Faisabilité : repositionnée au niveau du Plan d'action

Décision du 6 août 2026 (Théo) : **OIM, au niveau Vision, traite de l'opportunité — jamais de la faisabilité.** La faisabilité n'a de sens que face à une action ou un projet concret, pas face à un pilier abstrait. En conséquence :

- `FAISABILITE` est retirée des 9 analyses primaires (niveau Vision).
- Le **Plan d'action** devient explicitement une **famille de projets ou d'actions candidats, faisables ou pas** — chaque élément de la famille porte son propre verdict de faisabilité, jamais le Plan d'action dans son ensemble.
- Chaque action de la famille est validée et promue individuellement (déjà le comportement de `generate-actions`/`mg.plan_action_projects`) — le choix humain à la promotion **est** l'acte de sélection dans la famille.
- **Reste à construire** (chantier suivant, non traité par le présent ADR) : une génération de verdict de faisabilité par action, avant sa promotion, sur le même patron que l'interdépendance des interventions (niveau Plan d'action, sur un objet concret et nommé).

## 5. Interdépendance à deux niveaux — jamais une corrélation directe entre piliers

Décision du 5 août 2026 : l'interdépendance n'est jamais une relation scientifique directe entre deux piliers (`corr(A,B)` — relève de la recherche, pas d'OIM). Deux niveaux distincts :

- **Niveau Vision** — effets possibles d'un **levier** (pas encore un projet) sur d'autres piliers.
- **Niveau Plan d'action** — effets attendus d'un **projet réel nommé** sur d'autres piliers.

Une liste d'effets vide est un résultat scientifique légitime dans les deux cas — jamais forcée.

## 6. Réconciliation Chaîne A / Chaîne B

Découverte du 5 août 2026 : un système OIM parallèle et déconnecté (`mg.pillar_5whys_analysis`, `mg.pillar_root_causes` — Sprint "OIM Lot 1/2", conçu le 14 juillet, jamais alimenté de vraies données) coexistait avec la Vision construite cette semaine. Décision : l'entrée diagnostique redondante de la Chaîne A a été **supprimée** (remplacée par `osoa.strategic_analyses`/`5_POURQUOI`, validée sur données réelles) ; le catalogue de leviers a été **conservé et reconnecté** (voir §3).

## 7. Les deux agents IA d'OIM : SCRIBE et THEO

Nommés le 6 août 2026 (Théo), rôles strictement distincts :

- **SCRIBE** (rédacteur) — transcrit fidèlement les vraies données (ISA, POA, contenu déjà validé), n'invente jamais. Couvre toute génération primaire : les 9 analyses, le levier, les interdépendances, les résumés, les actions.
- **THEO** (réviseur) — juge un brouillon déjà produit par SCRIBE contre les vraies données et **exactement** les mêmes contraintes que SCRIBE a reçues (même schéma, même vocabulaire contrôlé). Ne rédige jamais lui-même. **Ne réinterprète jamais les données** (ne juge jamais si un chiffre est "significatif" selon son propre jugement — vérifie uniquement si une affirmation de SCRIBE est explicitement étayée).

Le verdict de THEO est structuré (`mg.analysis_review`) : `review_status` + une liste d'`issues`, chacune suivant impérativement **Règle violée → Preuve → Correction proposée** — jamais un commentaire libre.

**Le verdict de THEO n'est pas référentiel.** Ce n'est ni stable, ni normatif, ni partagé — c'est un jugement ponctuel sur une version précise d'un brouillon, à un instant donné. Il reste dans `mg.*` (journal d'audit), jamais dans `rf.*`. Traçable (horodaté, motivé), mais **non reproductible au sens strict** (une IA n'est pas déterministe) — traité comme une aide au tri humain, jamais comme une preuve scientifique en soi. L'autorité finale reste toujours humaine.

## 8. Amélioration de SCRIBE : leçons apprises, globales, validées humainement

SCRIBE n'apprend pas automatiquement des verdicts de THEO. Toute évolution durable du prompt de SCRIBE suit un principe strict, pour concilier coût et amélioration réelle :

- Les motifs récurrents des verdicts de THEO sont accumulés périodiquement.
- Un humain valide ces motifs avant toute intégration.
- Les leçons validées sont intégrées comme une section **globale** du prompt de SCRIBE — jamais spécialisées par pilier ou par pays tant que le volume réel de revues ne justifie pas une telle spécialisation (cohérent avec la doctrine de maturation progressive de l'ADR-011 : ne jamais construire sur une donnée qui n'existe pas encore).

## 9. Ce qui reste hors du périmètre d'OIM (inchangé depuis juillet)

OIM ne choisit pas les prestataires, ne pilote pas les consortiums, ne remplace pas un PMO, ne sélectionne pas les logiciels, ne décide pas des budgets, ne réalise pas la gestion contractuelle. Ces décisions demeurent de la responsabilité du maître d'ouvrage — cohérent avec le principe que **le Plan d'action expose une famille de candidats, jamais une réponse unique déjà tranchée** (voir §4).

## 10. Budget et échelle

À l'échelle annoncée (540 visions/an, 2020-2024, `rf.publication_policy.status = 'OFFICIAL'` uniquement) : 2 appels SCRIBE budgétés par étude d'opportunité (génération initiale + une régénération corrective éventuelle), encadrés par 1 appel THEO. Le pipeline batch OpenAI (`oim_batch.py`) couvre les 9 analyses primaires à l'échelle depuis le 6 août 2026 ; la mise en file en masse des leviers/interdépendance reste séquentielle, dépendante de la validation humaine préalable (ne peut pas être batchée en une seule vague comme les analyses primaires).

## 11. Relation avec ADR-OSA-OIM-001 (14 juillet 2026)

L'ADR de juillet décrivait une chaîne plus riche, jamais construite (`Transformation Requirement`, `Catalogue des Patrons d'Intervention`, `mg.intervention_patterns`, `mg.requirement_pattern_matches` — tous marqués *"développement non démarré"* dans le document d'origine). Statut : **remplacé en détail, aligné en esprit.**

- **Remplacé en détail** : la chaîne effectivement construite (§2) est plus simple — pas de catalogue de patrons d'intervention, pas de nœud "Transformation Requirement" séparé.
- **Aligné en esprit** : le principe central de juillet, *"OSA ne choisit jamais... une famille de réponses compatibles, jamais une réponse unique"* (§5 de l'ADR de juillet), **est respecté** — le Plan d'action expose une famille de projets/actions candidats (§4 du présent ADR), chacun validé et promu individuellement ; le choix final reste un acte humain explicite à la promotion, jamais une sélection automatique.
- Le "Catalogue des Patrons d'Intervention" reste une piste valable pour une maturation future (cohérent avec le phasage V1-V6 de l'ADR-011), mais n'est pas un prérequis à la doctrine actuelle du Plan d'action comme famille de candidats.

## Conséquences

- `ADR-OSA-OIM-001_final` passe au statut `SUPERSEDED_IN_DETAIL / ALIGNED_IN_SPIRIT` — conservé pour mémoire, ne doit plus être lu comme l'architecture cible.
- Le retrait de `FAISABILITE` des 9 analyses primaires et la construction d'un verdict de faisabilité par action (§4) restent un chantier de code à mener — non traité par le présent ADR, qui n'acte que la doctrine.
- Aucune modification de la hiérarchie OSA→ISA→POA→AMAR→GENECO, aucune saisine du Conseil scientifique panafricain requise.
- Les décisions dispersées des 4, 5 et 6 août 2026 (mémoire de session) sont désormais consolidées dans ce document unique — les futures évolutions doctrinales d'OIM doivent l'amender, plutôt que rouvrir des décisions déjà actées ici.
