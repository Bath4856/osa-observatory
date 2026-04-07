# OSA Observatory — Gouvernance des Zones Monétaires Africaines
## Guide de mise à jour de `rf.monetary_zone_history`

---

## Pourquoi cette table existe

En Afrique, la structure monétaire n'est pas figée. Des pays peuvent :
- Quitter une zone monétaire existante
- Créer une nouvelle monnaie commune
- Changer de banque centrale
- Modifier leur régime de change

L'ISA (Indice de Souveraineté Africaine) doit refléter ces évolutions pour rester
juste et traçable. La table `rf.monetary_zone_history` est le mécanisme prévu
pour gérer ces changements sans altérer les calculs historiques.

---

## Principe fondamental — Immuabilité du passé

> **On n'écrase jamais une entrée passée. On la ferme et on en crée une nouvelle.**

```sql
-- ❌ INTERDIT — modifie l'historique
UPDATE rf.monetary_zone_history
SET central_bank_type = 'AES'
WHERE country_iso3 = 'MLI';

-- ✅ CORRECT — ferme l'ancienne, ouvre la nouvelle
UPDATE rf.monetary_zone_history
SET valid_to = '2027-07-01'
WHERE country_iso3 = 'MLI' AND is_current;

INSERT INTO rf.monetary_zone_history (...) VALUES ('MLI', 'AES', ...);
```

---

## Cas d'usage 1 — Création de la monnaie AES (Mali, Niger, Burkina Faso)

**Contexte :** L'Alliance des États du Sahel (AES) a annoncé son intention de
créer une monnaie commune pour remplacer le franc CFA. Si ce projet se concrétise,
il faudra mettre à jour la table.

**Étapes :**

### 1. Vérifier l'état actuel
```sql
SELECT country_iso3, central_bank_type, currency_code, valid_from, valid_to
FROM rf.monetary_zone_history
WHERE country_iso3 IN ('MLI', 'NER', 'BFA')
AND is_current;
```

### 2. Fermer les entrées UEMOA
```sql
-- Remplacer AAAA-MM-JJ par la date officielle d'entrée en vigueur
UPDATE rf.monetary_zone_history
SET valid_to = 'AAAA-MM-JJ'
WHERE country_iso3 IN ('MLI', 'NER', 'BFA')
AND is_current;
```

### 3. Créer les nouvelles entrées AES
```sql
INSERT INTO rf.monetary_zone_history (
    country_iso3, central_bank_type, central_bank_code, central_bank_name,
    currency_code, currency_name, sovereignty_weight,
    valid_from, valid_to,
    source_reference, source_date, notes
) VALUES
    ('MLI', 'AES', 'BAES', 'Banque Centrale de l''Alliance des États du Sahel',
     'AES', 'Sahel (nom provisoire)', 0.850,
     'AAAA-MM-JJ', NULL,
     'Traité de création de la BAES — [référence officielle]',
     '[DATE]',
     'Passage de BCEAO/XOF à BAES/Sahel. Coefficient 0.850 (souveraineté '
     'partielle — banque commune mais politique monétaire autonome de l''UE).'),
    ('NER', 'AES', 'BAES', 'Banque Centrale de l''Alliance des États du Sahel',
     'AES', 'Sahel (nom provisoire)', 0.850,
     'AAAA-MM-JJ', NULL,
     'Traité de création de la BAES — [référence officielle]',
     '[DATE]', NULL),
    ('BFA', 'AES', 'BAES', 'Banque Centrale de l''Alliance des États du Sahel',
     'AES', 'Sahel (nom provisoire)', 0.850,
     'AAAA-MM-JJ', NULL,
     'Traité de création de la BAES — [référence officielle]',
     '[DATE]', NULL);
```

### 4. Vérifier l'absence de chevauchement
```sql
-- Vérifier que chaque pays n'a qu'une entrée active
SELECT country_iso3, COUNT(*) AS nb_actives
FROM rf.monetary_zone_history
WHERE is_current
GROUP BY country_iso3
HAVING COUNT(*) > 1;
-- Résultat attendu : 0 ligne
```

### 5. Vérifier le pipeline ISA
```sql
-- ISA 2023 doit utiliser UEMOA (avant la transition)
SELECT * FROM rf.monetary_zone_at('2023-12-31')
WHERE country_iso3 IN ('MLI', 'NER', 'BFA');
-- central_bank_type attendu : UEMOA

-- ISA 2028 doit utiliser AES (après la transition)
SELECT * FROM rf.monetary_zone_at('2028-01-01')
WHERE country_iso3 IN ('MLI', 'NER', 'BFA');
-- central_bank_type attendu : AES
```

### 6. Committer le changement
```sql
-- Créer un patch SQL versionné dans db/
-- Nommer : patch_aes_monnaie_AAAA.sql
-- Committer sur GitHub avec le message :
-- "Mise à jour zone monétaire AES — [date décision officielle]"
```

---

## Cas d'usage 2 — Révision du coefficient de souveraineté

**Exemple :** Une étude montre que le coefficient 0.700 pour les pays CFA
doit être révisé à 0.650 à partir de 2025 suite à une réforme du régime CFA.

```sql
-- Fermer les entrées actuelles
UPDATE rf.monetary_zone_history
SET valid_to = '2025-01-01'
WHERE central_bank_type IN ('UEMOA', 'CEMAC')
AND is_current;

-- Créer de nouvelles entrées avec le nouveau coefficient
INSERT INTO rf.monetary_zone_history (
    country_iso3, central_bank_type, central_bank_code, central_bank_name,
    currency_code, currency_name, sovereignty_weight,
    valid_from, valid_to, source_reference, notes
)
SELECT
    country_iso3, central_bank_type, central_bank_code, central_bank_name,
    currency_code, currency_name,
    0.650,  -- nouveau coefficient
    '2025-01-01', NULL,
    'Révision méthodologique OSA — [référence]',
    'Coefficient révisé suite à réforme CFA 2024'
FROM rf.monetary_zone_history
WHERE valid_to = '2025-01-01'
AND central_bank_type IN ('UEMOA', 'CEMAC');
```

---

## Cas d'usage 3 — Adhésion d'un nouveau pays à l'UEMOA

**Exemple :** La Guinée (GIN) rejoint l'UEMOA.

```sql
-- Fermer l'entrée NATIONAL
UPDATE rf.monetary_zone_history
SET valid_to = 'AAAA-MM-JJ'
WHERE country_iso3 = 'GIN' AND is_current;

-- Ouvrir la nouvelle entrée UEMOA
INSERT INTO rf.monetary_zone_history (
    country_iso3, central_bank_type, central_bank_code, central_bank_name,
    currency_code, currency_name, sovereignty_weight,
    valid_from, source_reference, notes
) VALUES (
    'GIN', 'UEMOA', 'BCEAO',
    'Banque Centrale des États de l''Afrique de l''Ouest',
    'XOF', 'Franc CFA ouest-africain', 0.700,
    'AAAA-MM-JJ',
    '[Traité d''adhésion]',
    'Adhésion de la Guinée à l''UEMOA. Remplacement du Franc guinéen (GNF) par XOF.'
);
```

---

## Requêtes utiles

### État monétaire à une date donnée
```sql
SELECT * FROM rf.monetary_zone_at('2024-01-01');
```

### État monétaire actuel
```sql
SELECT * FROM rf.monetary_zone_current;
```

### Historique complet d'un pays
```sql
SELECT
    central_bank_type, currency_code, sovereignty_weight,
    valid_from, valid_to, notes
FROM rf.monetary_zone_history
WHERE country_iso3 = 'MLI'
ORDER BY valid_from;
```

### Pays ayant changé de zone monétaire
```sql
SELECT country_iso3, COUNT(*) AS nb_changements
FROM rf.monetary_zone_history
GROUP BY country_iso3
HAVING COUNT(*) > 1
ORDER BY nb_changements DESC;
```

### Coefficient moyen par type pour une année ISA
```sql
SELECT
    h.central_bank_type,
    COUNT(*) AS nb_pays,
    AVG(h.sovereignty_weight) AS poids_moyen
FROM rf.monetary_zone_at('2024-01-01') h
GROUP BY h.central_bank_type;
```

---

## Coefficient de souveraineté — Grille de référence

| Situation | Coefficient | Justification |
|---|---|---|
| Banque centrale nationale indépendante | 1.000 | Pleine souveraineté monétaire |
| Zone monétaire régionale (CFA actuel) | 0.700 | Politique monétaire collective, réserves mutualisées, taux fixe |
| Zone monétaire nouvelle (AES prévu) | 0.850 | Banque commune mais politique plus autonome qu'UE/CFA |
| Union monétaire avancée (type EAC) | 0.800 | Coordination forte mais flexibilité partielle |
| Currency board / parité fixe | 0.900 | Autonomie partielle (choix unilatéral possible) |

> **Note :** Ces coefficients sont des approximations initiales. Ils seront
> révisés lors du Sprint ML en fonction des données empiriques 2010-2023.

---

## Règles de nommage des patches

Tout changement doit être versionné dans un fichier SQL séparé :

```
db/patch_monetary_[description]_[année].sql
```

Exemples :
- `db/patch_monetary_aes_monnaie_2027.sql`
- `db/patch_monetary_revision_cfa_2025.sql`
- `db/patch_monetary_guinee_uemoa_2026.sql`

Et committer sur GitHub avec un message explicite :
```
git commit -m "Zone monétaire : [description] — décision [date officielle]"
```

---

## Responsabilités

| Action | Qui | Quand |
|---|---|---|
| Surveiller les annonces officielles AES | Équipe OSA | Mensuel |
| Créer le patch SQL | Développeur OSA | Dès décision officielle |
| Valider le coefficient | Comité méthodologique | Avant mise en production |
| Vérifier l'impact ISA | Équipe analytique | Avant publication |
| Committer et déployer | Développeur OSA | Après validation |

---

*Document créé le 31 mars 2026 — OSA Observatory Sprint 3.5*
*À mettre à jour à chaque changement institutionnel majeur*