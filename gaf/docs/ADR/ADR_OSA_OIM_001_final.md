# ADR-OSA-OIM-001 (version finale) — Le moteur OIM comme chaîne d'ingénierie distincte

*Version finale au 14 juillet 2026, intégrant : (1) le repositionnement d'OIM hors de la hiérarchie scientifique ISA/POA/GENECO/AMAR, (2) l'insertion du Transformation Requirement entre l'Objectif stratégique et le Patron d'Intervention, (3) le renommage "Projet recommandé" → "Famille de projets compatibles". Remplace le texte initial d'ADR-OSA-OIM-001 fourni le 14 juillet 2026.*

---

| Champ | Valeur |
|---|---|
| **Code** | `ADR-OSA-OIM-001` |
| **Statut** | ACCEPTED *(architecture)* — développement non démarré |
| **Périmètre** | Chaîne d'ingénierie, distincte de la chaîne scientifique et distincte du diagnostic d'ADR-004 |
| **Dépend de** | ADR-004 (amendé, voir document séparé) — consomme l'Objectif stratégique qu'ADR-004 produit en sortie |
| **Organe de gouvernance** | Conseil technique OSA — ne touche à aucune ligne du Volume 0, ne requiert pas le Conseil scientifique panafricain |

## 1. Deux chaînes, deux registres, jamais mélangés

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

La chaîne scientifique observe et qualifie ; elle ne bascule jamais dans la prescription. La chaîne d'ingénierie conçoit des architectures d'intervention ; elle ne remplace jamais la chaîne scientifique et ne devient jamais elle-même un objet doctrinal du Volume 0.

## 2. La chaîne complète, avec la frontière ADR-004 / OIM explicite

```
Pilier
   ↓
5 Pourquoi
   ↓
Cause racine
   ↓
Levier stratégique
   ↓
Objectif stratégique
──────────────────────────────  fin d'ADR-004 — fin du diagnostic
   ↓
Transformation Requirement          ← nouveau nœud
   ↓
Catalogue des Patrons d'Intervention
   ↓
Patrons compatibles
   ↓
Instanciation
   ↓
Famille de projets compatibles      ← renommé (ex "Projet recommandé")
   ↓
Contribution stratégique attendue
```

**ADR-004 répond à « pourquoi faut-il agir ? ». OIM répond à « quelles architectures d'intervention sont compatibles avec ce besoin ? ».** Ce ne sont pas la même question, et aucune des deux ne répond à « que faut-il faire, précisément, et avec qui ? » — cette dernière question reste, comme le §7 de la version initiale le précisait déjà, hors du périmètre d'OSA : elle appartient au maître d'ouvrage.

## 3. Le Transformation Requirement — un objet, pas un champ de texte

Un même Objectif stratégique peut se décomposer en plusieurs besoins de transformation distincts (exemple : « réduire les pertes de valeur dans la filière minière » se décompose en besoins de gouvernance documentaire, de traçabilité, de certification, de contrôle des exportations — des besoins différents, pas un besoin unique qui matcherait sept patrons par coïncidence).

- **Objectif stratégique → Transformation Requirement : 1:N.** Un objectif peut engendrer plusieurs exigences de transformation distinctes.
- **Transformation Requirement → Patron d'Intervention : N:N**, pondérée, symétrique aux relations déjà actées dans ADR-004 (`root_cause_levers`, `lever_objectives`). Une exigence peut être satisfaite par plusieurs patrons compatibles ; un patron peut répondre à plusieurs exigences dans des contextes différents.

## 4. Ce que devient l'explicabilité

Aucun champ « Explication » séparé n'est nécessaire : la traversée complète de la chaîne (Objectif → Transformation Requirement → Patron compatible → Instanciation → Famille de projets) constitue elle-même la trace explicative. Pour tout projet, on peut remonter exactement la suite de décisions référentielles qui y a conduit — c'est la définition même de l'auditabilité (Principe 2, Volume 0), sans qu'un champ de texte libre supplémentaire soit requis.

## 5. OSA ne choisit jamais — renforcé, pas seulement maintenu

« Projet recommandé » est remplacé par **Famille de projets compatibles** : OSA caractérise un ensemble de réponses possibles (ex. GED, archivage électronique, numérisation, records management, workflow documentaire pour le patron « gouvernance documentaire »), il ne désigne jamais une réponse unique. Le choix final appartient exclusivement au maître d'ouvrage ou au consortium — cohérent avec le §7 (domaine exclu) de la version initiale de cet ADR, qui reste inchangé.

## 6. Domaine exclu (inchangé depuis la version initiale)

OIM ne choisit pas les prestataires, ne pilote pas les consortiums, ne remplace pas un PMO, ne sélectionne pas les logiciels, ne décide pas des budgets, ne réalise pas la gestion contractuelle. Ces décisions demeurent de la responsabilité du maître d'ouvrage.

## 7. Conséquences

- ADR-004 doit être amendé pour recadrer son périmètre sur « Pilier → Objectif stratégique » exclusivement (voir document séparé).
- Aucune modification du Volume 0, aucune saisine du Conseil scientifique panafricain requise pour cette décision.
- Objets à créer en Phase 1 d'OIM (numérotation à faire correspondre à votre registre) : `mg.transformation_requirements`, `mg.intervention_patterns` (le catalogue des Patrons), `mg.requirement_pattern_matches` (relation N:N pondérée), et une table d'instanciation reliant patron compatible → famille de projets.
- Raccordement avec le Livre Blanc Go-To-Market (ADR-003, schéma `gtm`) inchangé par rapport à ce qui avait déjà été noté : une famille de projets compatibles issue d'OIM reste un candidat naturel à `gtm.deliverables` (famille `DECISION`), sans lien technique construit à ce stade.
