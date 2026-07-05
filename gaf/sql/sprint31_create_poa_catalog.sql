-- ============================================================
-- Sprint 31 -- Elimination des donnees en dur d'IosaDetail.jsx
-- Creation de rf.poa_catalog + correction du titre PMIN_SMUGGLING
-- 4 juillet 2026
-- ============================================================
-- Doctrine "tout en base" : les libelles, descriptions et textes de
-- tendance des 3 indicateurs POA etaient codes en dur dans le composant
-- React (INDICATOR_CONFIG). Ce script les deplace en base sans rien
-- perdre -- contenu repris integralement, mot pour mot.
--
-- Choix de conception : pas de colonne titre/label dans poa_catalog.
-- rf.indicators.name_fr / name_en reste l'unique source de verite pour
-- le titre public (deja identique au label attendu pour 2 indicateurs
-- sur 3) -- evite la duplication titre/titre_fk. Idem pour pillar_code,
-- deja porte par rf.indicators, jamais duplique ici.
--
-- Toutes les valeurs textuelles utilisent le dollar-quoting Postgres
-- pour eliminer tout risque d'apostrophe mal echappee (cf. bug finding #31).
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint31_create_poa_catalog.sql
-- ============================================================

BEGIN;

-- 1) Alignement du titre PMIN_SMUGGLING_SIGNAL_RANK sur le libelle public
--    deja affiche par le portail (plus clair que la version technique
--    "(ordinal)" actuellement en base)
UPDATE rf.indicators
SET name_fr = $t$Signal de contrebande minière$t$,
    name_en = $t$Mineral smuggling signal$t$
WHERE code = 'PMIN_SMUGGLING_SIGNAL_RANK';

-- 2) Table de catalogue POA
CREATE TABLE IF NOT EXISTS rf.poa_catalog (
    indicator_code   varchar(30) PRIMARY KEY REFERENCES rf.indicators(code) ON DELETE CASCADE,
    delta_desc_fr    text NOT NULL,
    delta_desc_en    text NOT NULL,
    metric_label_fr  text NOT NULL,
    metric_label_en  text NOT NULL,
    metric_note_fr   text NOT NULL,
    metric_note_en   text NOT NULL,
    source_fr        text NOT NULL,
    source_en        text NOT NULL,
    coverage_fr      text NOT NULL,
    coverage_en      text NOT NULL,
    warning_fr       text,
    warning_en       text,
    tendency_up_fr   text NOT NULL,
    tendency_up_en   text NOT NULL,
    tendency_down_fr text NOT NULL,
    tendency_down_en text NOT NULL,
    tendency_flat_fr text NOT NULL,
    tendency_flat_en text NOT NULL,
    display_order    integer NOT NULL DEFAULT 0,
    updated_at       timestamp NOT NULL DEFAULT now()
);

-- 3) Seed -- contenu repris integralement d'INDICATOR_CONFIG (IosaDetail.jsx)

INSERT INTO rf.poa_catalog (
    indicator_code, delta_desc_fr, delta_desc_en,
    metric_label_fr, metric_label_en, metric_note_fr, metric_note_en,
    source_fr, source_en, coverage_fr, coverage_en,
    warning_fr, warning_en,
    tendency_up_fr, tendency_up_en, tendency_down_fr, tendency_down_en,
    tendency_flat_fr, tendency_flat_en, display_order
) VALUES
(
    'PHUM_VALUE_CAPTURE',
    $t$Mesure l'écart entre le capital humain formé sur le territoire et celui qui y reste. Un delta négatif croissant signale une hémorragie de compétences — médecins, ingénieurs, cadres qui quittent le pays après leur formation.$t$,
    $t$Measures the gap between human capital trained on the territory and human capital that stays. A growing negative delta signals a brain drain — doctors, engineers, executives leaving the country after training.$t$,
    $t$Rétention observée (%)$t$,
    $t$Observed retention (%)$t$,
    $t$Part du capital humain formé retenu sur le territoire. Un chiffre en baisse indique que la fuite s'accélère.$t$,
    $t$Share of trained human capital retained on the territory. A declining figure indicates accelerating outflow.$t$,
    $t$Banque mondiale (WB SH.MED.PHYS.ZS + SE.TER.ENRR)$t$,
    $t$World Bank (WB SH.MED.PHYS.ZS + SE.TER.ENRR)$t$,
    $t$54 pays · 2010–2024$t$,
    $t$54 countries · 2010–2024$t$,
    NULL, NULL,
    $t$La rétention du capital humain se dégrade sur la période — le pays perd proportionnellement plus de compétences formées qu'il n'en retient.$t$,
    $t$Human capital retention is deteriorating over the period — the country is losing a proportionally higher share of its trained skills.$t$,
    $t$La rétention du capital humain s'améliore sur la période — une part croissante des compétences formées reste sur le territoire.$t$,
    $t$Human capital retention is improving over the period — a growing share of trained skills remains on the territory.$t$,
    $t$La rétention du capital humain est stable sur la période observée.$t$,
    $t$Human capital retention is stable over the observed period.$t$,
    1
),
(
    'PMIN_VALUE_LEAKAGE',
    $t$Mesure l'écart entre ce que les partenaires commerciaux déclarent avoir reçu et ce que le pays déclare avoir exporté, sur les minerais stratégiques. Ce delta représente la valeur qui quitte le territoire sans être déclarée ni capturée — une hémorragie commerciale mesurable.$t$,
    $t$Measures the gap between what trading partners declare having received and what the country declares having exported, on strategic minerals. This delta represents value leaving the territory undeclared and uncaptured — a measurable commercial hemorrhage.$t$,
    $t$Fuite déclarée (%)$t$,
    $t$Declared leakage (%)$t$,
    $t$Pourcentage de la valeur minérale reçue par les partenaires qui n'a pas été déclarée à l'export par le pays. Plus ce chiffre est élevé, plus l'hémorragie est importante.$t$,
    $t$Percentage of mineral value received by partners that was not declared as an export by the country. The higher this figure, the greater the hemorrhage.$t$,
    $t$CEPII BACI HS92 (HS26 + HS27 + HS71)$t$,
    $t$CEPII BACI HS92 (HS26 + HS27 + HS71)$t$,
    $t$54 pays · 2010–2024$t$,
    $t$54 countries · 2010–2024$t$,
    NULL, NULL,
    $t$La fuite de valeur minière s'aggrave sur la période — une proportion croissante des minerais exportés échappe à la déclaration officielle.$t$,
    $t$Mineral value leakage is worsening over the period — a growing share of exported minerals escapes official declaration.$t$,
    $t$La fuite de valeur minière se réduit sur la période — la part des minerais non déclarés diminue.$t$,
    $t$Mineral value leakage is decreasing over the period — the share of undeclared minerals is declining.$t$,
    $t$La fuite de valeur minière est stable sur la période observée.$t$,
    $t$Mineral value leakage is stable over the observed period.$t$,
    2
),
(
    'PMIN_SMUGGLING_SIGNAL_RANK',
    $t$Mesure l'écart entre la production minérale estimée et les flux commerciaux déclarés. Un rang élevé indique que l'écart entre production et déclaration est suspect — une configuration méritant une investigation complémentaire. Cet indicateur ne désigne aucune responsabilité.$t$,
    $t$Measures the gap between estimated mineral production and declared trade flows. A high rank indicates that the gap between production and declaration is suspicious — a configuration warranting further investigation. This indicator assigns no responsibility.$t$,
    $t$Rang de suspicion$t$,
    $t$Suspicion rank$t$,
    $t$Rang ordinal construit à partir de l'écart production/déclaration. Un rang élevé signale une configuration atypique — pas une certitude de contrebande.$t$,
    $t$Ordinal rank built from the production/declaration gap. A high rank signals an atypical configuration — not a certainty of smuggling.$t$,
    $t$BACI × USGS (MIN_PRD_*)$t$,
    $t$BACI × USGS (MIN_PRD_*)$t$,
    $t$37 pays · 2016–2021$t$,
    $t$37 countries · 2016–2021$t$,
    $t$Série partielle — couverture 2016–2021 pour 37 pays. Les années hors de cette fenêtre n'ont pas de données observées et ne sont pas publiées.$t$,
    $t$Partial series — 2016–2021 coverage for 37 countries. Years outside this window have no observed data and are not published.$t$,
    $t$Le rang de suspicion s'aggrave sur la période — l'écart entre production estimée et flux déclarés s'élargit.$t$,
    $t$The suspicion rank is worsening over the period — the gap between estimated production and declared flows is widening.$t$,
    $t$Le rang de suspicion diminue sur la période — l'écart entre production estimée et flux déclarés se réduit.$t$,
    $t$The suspicion rank is decreasing over the period — the gap between estimated production and declared flows is narrowing.$t$,
    $t$Le rang de suspicion est stable sur la période observée.$t$,
    $t$The suspicion rank is stable over the observed period.$t$,
    3
)
ON CONFLICT (indicator_code) DO NOTHING;

COMMIT;

-- Verification post-execution
SELECT indicator_code, metric_label_fr, coverage_fr, display_order
FROM rf.poa_catalog
ORDER BY display_order;
