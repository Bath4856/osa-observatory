# 06_Frontend — Portail React

*Section de l'OSA Architecture Knowledge Base (AKB). Source : `portail.zip` (97 fichiers, hors les 10 fichiers `Theo_a_confirmer/` exclus par décision du 14 juillet 2026, et hors les zips imbriqués déjà documentés en `01_Inventory` / onglet `Zips_Imbriques`). Établi le 14 juillet 2026. Catalogue détaillé : `06_Frontend_Catalog.xlsx`.*

---

## 1. Architecture générale (`App.jsx`)

React Router (`createBrowserRouter`). Une page (`/confirm-email`) est volontairement hors du `Layout` principal (pas de header/navigation complet) — commentaire explicite dans le code : *« accédée via un lien/QR personnel (flyer, e-mail d'invitation), pas par une navigation normale »*. Toutes les autres routes partagent un `Layout` commun : `AppHeader` + `KycReminderBanner` + contenu + `AppFooter`.

`AuthContext.jsx` gère la session via `localStorage` (`osa_auth`) et appelle `POST /api/v2/affiliates/auth/login` — cohérent avec `05_API`.

## 2. Finding important : cinq fichiers importés par `App.jsx` sont absents de l'archive

`App.jsx` importe et route explicitement :

```
import AppHeader from './components/AppHeader/AppHeader'
import Home from './pages/Home'
import CountryISA from './pages/CountryISA'
import Projects from './pages/Projects'
import ProjectDetail from './pages/ProjectDetail'
```

**Aucun de ces cinq fichiers n'existe dans `portail.zip`** — ni `components/AppHeader/`, ni `pages/Home.jsx`, `CountryISA.jsx`, `Projects.jsx`, `ProjectDetail.jsx`. Avec ces fichiers manquants, le portail tel que livré dans cette archive ne compilerait pas en l'état (imports non résolus).

**Explication la plus probable** : `portail.zip` est un export partiel du dossier `src/` (cohérent avec la remarque déjà connue : `H:\doc\portail` est un dossier de transit, pas un clone Git complet) plutôt qu'un bug réel du site en production. Impossible de le confirmer depuis les seules sources chargées — **à vérifier auprès du dépôt Git réel (`G:\osa-observatory`, branche `main`) avant de tirer une conclusion sur l'état du site live.**

## 3. Quatre pages orphelines (jamais routées)

Comme pour les routeurs API non câblés (`05_API`), certains fichiers de `pages/` existent mais ne sont référencés dans aucune route de `App.jsx` :

| Fichier | Constat |
|---|---|
| `AlertDetail.jsx` | Page complète, jamais routée nulle part |
| `Login_v2.jsx` | Variante de `Login.jsx` (qui, elle, est routée sur `/login`), jamais utilisée |
| `ConfirmEmail_v2.jsx` | Variante de `ConfirmEmail.jsx` (routée), jamais utilisée |
| `AmarDetail_no_gen.jsx` | Variante de `AmarDetail.jsx` (routée sur `/country/:iso3/amar`), jamais utilisée |

Même motif que les variantes `opendata_FIXED`/`GENECO`/`GENECO_v2` côté API : des versions alternatives coexistent avec la version active sans qu'aucune des deux ne soit supprimée ni clairement marquée comme obsolète.

## 4. i18n — bonne nouvelle : parité complète FR/EN

Vérification automatique : **`fr.json` et `en.json` comptent chacun exactement 152 clés, et les deux jeux de clés sont strictement identiques** (aucune clé présente dans l'un et absente de l'autre). C'est une confirmation concrète, au niveau du code, que le Principe 8 du Volume 0 (« le bilinguisme est intégré dès la conception ») est effectivement respecté dans le portail — pas seulement une intention doctrinale.

## 5. `about_content.json` — confirmation d'un fichier mort

`src/constent/about_content.json` (10,9 Ko — noter au passage la coquille du nom de dossier, `constent` pour `content`, qui existe telle quelle dans l'archive) **n'est importé par aucun fichier `.jsx`/`.js` actif de cette archive**. Ceci confirme, au niveau du code et non plus seulement de la mémoire du projet, la note déjà connue : *« i18n unifié : `about_content.json` supprimé, `fr.json`/`en.json` source unique de vérité »* (Sprint 31). Le fichier n'a en réalité pas été supprimé du répertoire de travail — il est simplement devenu orphelin. À supprimer physiquement si l'objectif est un nettoyage complet.

## 6. `alerts.js` vs `alerts-old.js`

`src/api/alerts-old.js` porte le suffixe `-old` de façon explicite et documente une performance de ~40 ms par endpoint. Le fichier actif `alerts.js` s'appuie sur une vue matérialisée composite (`ma.mv_p7i_amar_composite_dashboard`, ~86 ms contre ~48 s pour les vues simples non matérialisées) — cohérent avec le fichier `sprint29_mv_amar_geneco_dashboard.sql` déjà catalogué en `04_SQL`. Contrairement aux autres duplications de cette section, celle-ci est sans ambiguïté : le nommage `-old` suffit à lui seul à clarifier laquelle est active.

## 7. Duplication déjà traitée ailleurs

`portail/api/` (3 fichiers : `main.py`, `admin_affiliates.py`, `auth_affiliates.py`) duplique le contenu d'`api.zip`, déjà analysé en détail dans `05_API` — non répété ici. `portail/create_founder_account_preprod.sql` est identique (hash MD5) au fichier du même nom dans `gaf.zip` — voir `01_Inventory` / `Doublons_Exacts` (DUP-009).

## 8. Composants et contenu

- **Composants** : `AppFooter`, `CountryMap`, `KycReminderBanner`, `ScoreTable` — 4 composants réutilisables présents dans l'archive (`AppHeader`, référencé par `App.jsx`, est absent — voir point 2).
- **Contenu structuré** (`src/constent/`, `src/data/pillarData.js`) : `amarContent.js` et `genecoContent.js` (~9,7 Ko chacun) portent vraisemblablement les textes explicatifs AMAR/GENECO affichés côté portail — cohérents avec la doctrine de neutralité du Volume 0 (Principe 3) si leur contenu se limite à expliquer la méthode sans l'interpréter ; non vérifié ligne à ligne dans cette passe.
- **Assets** : deux logos PNG (`logo_header.png`, `logo_osa_transparent.png`), non analysés au-delà de leur présence.

## 9. Catalogue des pages (voir `06_Frontend_Catalog.xlsx`)

21 pages dans `src/pages/` (hors `Theo_a_confirmer/`), dont 17 routées dans `App.jsx` et 4 orphelines (section 3 ci-dessus), plus 5 routes de `App.jsx` pointant vers des fichiers absents de l'archive (section 2).
