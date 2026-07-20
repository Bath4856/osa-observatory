# 08_Governance — Gouvernance institutionnelle

*Section de l'OSA Architecture Knowledge Base (AKB). Sources : `docs.zip` (chartes, notes de présentation, décisions de feuille de route, GAF de gouvernance). Établi le 14 juillet 2026. La gouvernance *opérationnelle* des actifs techniques (GAF, ADR, audit) est déjà couverte en `02_GAF` et `03_ADR` — cette section ne la répète pas et se concentre sur la gouvernance *institutionnelle* (organes, mandats, rôles).*

---

## 1. Le Conseil scientifique panafricain

`docs/OSA_Charte_Neutralite_Scientifique_Interne_v1.docx` (Mai 2026, confidentiel, usage interne) fixe la charte complète de l'organe qui détient l'autorité doctrinale suprême sur les contenus scientifiques de l'OSA.

### Composition cible
7 à 10 membres permanents, avec quatre critères simultanés : au moins un expert par région africaine (Nord, Ouest, Centre, Est, Australe) ; mixité disciplinaire (économistes, statisticiens, politologues, spécialistes données, juristes) ; indépendance structurelle (aucun mandat gouvernemental actif, aucun poste exécutif dans une institution finançant l'OSA) ; au moins 40 % de femmes. Mandats de 3 ans, non renouvelables — protection explicite contre la capture institutionnelle.

### Autorité exclusive et non délégable
Validation des pondérations de piliers et des bornes de normalisation, approbation de tout changement doctrinal (sources, indicateurs, seuils), certification de chaque publication ISA avant diffusion, validation des résultats Monte Carlo de sensibilité, révision des seuils AMAR (GREEN→BLACK), décision d'inclusion/exclusion d'un indicateur.

### Règles éthiques
Déclaration d'intérêts annuelle obligatoire ; récusation automatique pour tout pays dont un membre est ressortissant (5 dernières années), tout pays où il a des intérêts économiques directs, ou tout indicateur/source dont il est l'auteur — récusation consignée en procès-verbal et rendue publique dans le rapport annuel ; confidentialité stricte des scores non publiés.

### Procédures de vote
| Type de décision | Quorum | Majorité |
|---|---|---|
| Certification d'une publication ISA | 5/7 | Simple (4/5) |
| Modification des pondérations de piliers | 6/7 | Qualifiée (2/3) |
| Changement doctrinal majeur | 7/7 | Unanimité |
| Révocation d'un membre | 6/7 | Qualifiée (2/3) |

Sessions ordinaires deux fois par an (janvier, juillet) ; sessions extraordinaires sur demande du président ou de 3 membres ; session de certification avant chaque publication officielle.

### Écart doctrine / réalité actuelle à signaler explicitement

`docs/OSA_Conseil_Scientifique_Note_Presentation_v1.docx` précise : **lancement officiel du Conseil au 3 septembre 2027, candidatures de membres fondateurs attendues avant le 1er février 2027.** Autrement dit, à la date de cet inventaire (14 juillet 2026), l'ensemble de l'appareil de gouvernance décrit ci-dessus (quorum de 7, sessions bisannuelles, récusations, etc.) est une **cible statutaire, pas un organe actuellement en fonction**. C'est cohérent avec l'état réel déjà connu du projet (Théo D. Bakang comme unique compte ADMIN actif dans les 3 comités en préprod, cooptation des premiers collaborateurs encore en cours). Cette charte doit être lue comme le règlement intérieur *préparé pour* l'organe à venir, pas comme une description de son fonctionnement courant.

## 2. Le modèle des six rôles d'affiliation

`docs/gaf_eparticipation_role_matrix_001.docx` (GAF finding `EPARTICIPATION_ROLE_MATRIX_001`, Sprint 30 Lot D, 29 juin 2026) fixe le modèle de rôles applicable à l'ensemble du système d'affiliation :

| Rôle | Profil | Périmètre |
|---|---|---|
| `ADMIN` | Équipe OSA | Gestion globale, affiliations, gouvernance D4 |
| `COMITE_TECH` | Conseil technique OSA | Validation technique, groupes de travail, préprod |
| `COMITE_SCI` | Comité scientifique OSA | Validation méthodologique, vote exclusif D3 |
| `COMITE_ETHIQUE` | Comité éthique OSA *(prospectif)* | Commentaires D2 — futur pilier Indice Africain de Gouvernance |
| `AFFILIE` | Organisation ou personne affiliée | Contributions D1, historique personnel, groupes D4 |
| `OBSERVATEUR` | Visiteur identifié | Accès portail public uniquement |

**`COMITE_ETHIQUE` est une mise à jour par rapport à ce qui était connu jusqu'ici** (le modèle à cinq rôles ADMIN/COMITE_TECH/COMITE_SCI/AFFILIE/OBSERVATEUR). Il a été ajouté au modèle de données dès le Sprint 30, en anticipation d'un futur produit analytique — l'Indice Africain de Gouvernance, conçu pour suivre la même doctrine P7E (données primaires observées) déjà appliquée à l'ISA et à la classe IOSA (voir `07_Methodology` §2) — **sans qu'aucun affilié n'y soit nécessairement assigné avant le lancement de ce produit**. C'est un rôle réservé, pas encore peuplé.

La matrice complète des droits par sous-lot (D1 contributions traçables, D2 commentaires, D3 votes méthodologiques, D4 groupes de travail) est détaillée dans le document source ; le principe général retenu est qu'**aucune fonctionnalité collaborative n'est ouverte sans matrice de droits explicite par rôle** — cohérent avec le Principe 6 du Volume 0 (gouvernance intégrée dès la conception).

## 3. La feuille de route stratégique (Décision 10D)

`docs/OSA_Decision_10D_V2_Feuille_Route_2026_2027.docx` (décision formalisée le 22 mai 2026, Sprint 10) fixe le cadre stratégique qui structure toute l'activité 2026-2027 :

- **2026 = phase d'appropriation**, explicitement *pas* une publication définitive d'un classement — publication progressive pays par pays, à destination des chercheurs, universités et partenaires institutionnels.
- **Année de référence 2026** : 2022 (pipeline validé, AMAR propre : 0 RED, 1 ORANGE, 53 YELLOW à cette date de référence).
- **Lancement consolidé : septembre 2027** — multi-pays, multi-piliers, série temporelle complète. C'est la même date que le lancement officiel du Conseil scientifique (section 1) — les deux événements sont synchronisés par construction.
- **P7Z (couche prédictive) en 2026** : accès restreint aux partenaires institutionnels sous charte, non exposé publiquement — cohérent avec le blocage `PENDING_SCIENTIFIC_COMMITTEE_VALIDATION` déjà connu, et avec la confirmation faite en `04_SQL` que les fichiers `patch_p7z_*.sql` sont déployés en base mais non activés.
- **P7F/P7X** : P7X (SWOT, commit `3455cb7`, 2014 lignes) archivé et remplacé par P7F « doctrine pure », 8 091 diagnostics SWOT actifs à la date de la décision. Moteur commercial P7J prévu Sprint 11.
- **Charte scientifique** : initiation actée dès le Sprint 11 — c'est cette décision de Sprint 10 qui déclenche la rédaction de la charte détaillée en section 1.

## 4. Ce que cette section n'a pas couvert

- `OSA_Charte_Neutralite_Scientifique_Publique_v1.docx` (version publique, probablement condensée depuis la version interne) n'a pas été comparée en détail à la version interne pour vérifier la cohérence entre les deux — à faire si les deux textes doivent être publiés côte à côte.
- `OSA_Synthese_Institutionnelle_V2_Mai2026.docx`, `OSA_Zachman_Synthese_Institutionnelle_Sprint11.docx` et les rapports de clôture de sprint (`rapport_cloture_sprint30.docx`, `rapport_cloture_sprints_27_28_29.docx`) n'ont pas été dépouillés dans cette passe.
- Cette section documente les textes de gouvernance tels qu'écrits ; elle ne vérifie pas si les procédures décrites (déclarations d'intérêts, sessions de certification) ont déjà été exercées en pratique — logique, puisque le Conseil lui-même n'est pas encore constitué (section 1).
