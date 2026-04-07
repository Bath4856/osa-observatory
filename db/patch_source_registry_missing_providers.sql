-- ============================================================
-- OSA / ISA OBSERVATORY
-- patch_source_registry_missing_providers.sql
-- ============================================================
-- Insère les 9 providers Python absents de collect.source_registry.
-- Les providers existants (WB, IMF, FAO, WHO, ACLED) ne sont pas
-- touchés grâce au ON CONFLICT DO NOTHING.
-- ============================================================

BEGIN;

INSERT INTO collect.source_registry (
    source_id, name, organization, api_type, base_url,
    status, priority,
    coverage, stability, limits, reason,
    freshness_score, completeness_score, reliability_score,
    is_active
)
VALUES

-- ── IMF — sous-endpoints CSV (priorité 1 comme IMF parent) ──────────────
('IMF_WEO',
 'IMF World Economic Outlook (CSV)',
 'International Monetary Fund',
 'CSV_BULK',
 'https://www.imf.org/en/Publications/WEO/weo-database/',
 'GO', 1,
 '54 pays africains — 10 indicateurs PMON/PECO',
 'HIGH',
 'Téléchargement manuel annuel (avril/octobre)',
 'Remplace fetcher_imf API — plus fiable, pas de timeout',
 0.90, 0.85, 0.95,
 TRUE),

('IMF_DOTS',
 'IMF Direction of Trade Statistics (CSV)',
 'International Monetary Fund',
 'CSV_BULK',
 'https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85',
 'GO', 1,
 '54 pays africains — indicateurs flux commerciaux',
 'HIGH',
 'Téléchargement annuel',
 NULL,
 0.88, 0.80, 0.92,
 TRUE),

('IMF_BOP',
 'IMF Balance of Payments (CSV)',
 'International Monetary Fund',
 'CSV_BULK',
 'https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52',
 'GO', 1,
 '54 pays africains — balance des paiements',
 'HIGH',
 'Téléchargement annuel',
 NULL,
 0.88, 0.78, 0.90,
 TRUE),

-- ── ITU ─────────────────────────────────────────────────────────────────
('ITU',
 'ITU World Telecommunication Indicators',
 'International Telecommunication Union',
 'API_JSON',
 'https://datahub.itu.int/api/',
 'GO', 2,
 '54 pays africains — indicateurs numériques PNUM',
 'MEDIUM',
 'Rate limit modéré',
 NULL,
 0.82, 0.75, 0.85,
 TRUE),

-- ── UNESCO ──────────────────────────────────────────────────────────────
('UNESCO',
 'UNESCO Institute for Statistics',
 'UNESCO',
 'API_JSON',
 'https://api.uis.unesco.org/',
 'GO', 2,
 '53 pays africains — 4 indicateurs HUM, sans clé API',
 'MEDIUM',
 NULL,
 NULL,
 0.80, 0.72, 0.83,
 TRUE),

-- ── UNDP ────────────────────────────────────────────────────────────────
('UNDP',
 'UNDP Human Development Report (CSV)',
 'United Nations Development Programme',
 'CSV_BULK',
 'https://hdr.undp.org/data-center/documentation-and-downloads',
 'GO', 2,
 '54 pays africains — HUM_EDU, HUM_GEN, HUM_LIT (1990-2022)',
 'HIGH',
 'CSV direct, sans clé',
 NULL,
 0.85, 0.80, 0.88,
 TRUE),

-- ── EITI ────────────────────────────────────────────────────────────────
('EITI',
 'Extractive Industries Transparency Initiative (CSV)',
 'EITI International Secretariat',
 'CSV_BULK',
 'https://eiti.org/data',
 'GO', 3,
 'Pays membres EITI en Afrique — revenus extractifs',
 'MEDIUM',
 'Couverture partielle (pays membres uniquement)',
 NULL,
 0.78, 0.65, 0.80,
 TRUE),

-- ── SIPRI ───────────────────────────────────────────────────────────────
('SIPRI',
 'SIPRI Military Expenditure Database (CSV)',
 'Stockholm International Peace Research Institute',
 'CSV_BULK',
 'https://www.sipri.org/databases/milex',
 'GO', 3,
 '54 pays africains — dépenses militaires',
 'HIGH',
 'Téléchargement annuel Excel/CSV',
 NULL,
 0.88, 0.82, 0.90,
 TRUE),

-- ── USGS ────────────────────────────────────────────────────────────────
('USGS',
 'USGS Mineral Resources Data System (CSV)',
 'U.S. Geological Survey',
 'CSV_BULK',
 'https://mrdata.usgs.gov/',
 'PILOT', 4,
 'Pays africains producteurs — ressources minérales',
 'MEDIUM',
 'Couverture variable selon les minerais',
 'En évaluation — couverture africaine à confirmer',
 0.72, 0.60, 0.75,
 TRUE)

ON CONFLICT (source_id) DO NOTHING;

-- ── Vérification post-insertion ──────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.source_registry
    WHERE source_id IN (
        'WB','IMF','IMF_WEO','IMF_DOTS','IMF_BOP',
        'WHO','ITU','FAO','UNDP','UNESCO',
        'EITI','SIPRI','USGS','ACLED'
    );
    RAISE NOTICE 'Providers enregistrés dans source_registry : % / 14', v_count;
END;
$$;

COMMIT;
