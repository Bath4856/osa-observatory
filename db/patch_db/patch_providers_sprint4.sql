-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : Nouveaux providers Sprint 4
-- Date  : 2026-04-01
-- Ajout : UNESCO UIS, et correction ILO, FAO, ITU, SIPRI
-- ============================================================
BEGIN;

-- UNESCO
INSERT INTO collect.data_providers (code, name, base_url, reliability_score, is_active, description)
VALUES ('UNESCO', 'UNESCO Institute for Statistics',
        'https://api.uis.unesco.org/api/public/data/', 0.90, true,
        'API publique UIS — education, alphabetisation, STEM.')
ON CONFLICT (code) DO UPDATE SET is_active = true;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, is_active)
VALUES (
    (SELECT id FROM collect.data_providers WHERE code = 'UNESCO'),
    'UNESCO_UIS_INDICATOR',
    'UNESCO UIS — indicateurs education',
    'https://api.uis.unesco.org/api/public/data/indicators?indicator={uis_code}&countryCode={iso3}&format=json',
    'json', true
) ON CONFLICT DO NOTHING;

INSERT INTO mm.source_origins
    (code, name, source_type, license_type, api_url, website,
     reliability_score, update_frequency, description)
VALUES ('UNESCO', 'UNESCO Institute for Statistics',
        'international', 'open',
        'https://api.uis.unesco.org/api/public/data/',
        'https://uis.unesco.org', 0.90, 'yearly',
        'Statistiques education, alphabetisation, STEM par pays africains.')
ON CONFLICT (code) DO NOTHING;

-- UNDP (correction si absent apres restart)
INSERT INTO collect.data_providers (code, name, base_url, reliability_score, is_active, description)
VALUES ('UNDP', 'UNDP HDR Data',
        'https://hdr.undp.org/sites/default/files/2023-24_HDR/', 0.90, true,
        'CSV HDR23-24 — HUM_EDU, HUM_GEN, HUM_LIT. Sans auth.')
ON CONFLICT (code) DO UPDATE SET is_active = true;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, is_active)
VALUES (
    (SELECT id FROM collect.data_providers WHERE code = 'UNDP'),
    'UNDP_HDI',
    'UNDP — IDH et composantes',
    'https://hdrdata.org/api/composite/country/all/{undp_code}',
    'json', true
) ON CONFLICT DO NOTHING;

INSERT INTO mm.source_origins
    (code, name, source_type, license_type, api_url, website,
     reliability_score, update_frequency, description)
VALUES ('UNDP', 'Programme des Nations Unies pour le dev.',
        'international', 'open',
        'https://hdr.undp.org',
        'https://hdr.undp.org', 0.90, 'yearly',
        'Indices IDH, GII, EYS, MYS — 206 pays.')
ON CONFLICT (code) DO NOTHING;

COMMIT;

DO $$
BEGIN
    RAISE NOTICE 'PATCH OK — providers Sprint 4 configures';
    RAISE NOTICE '  UNESCO : provider + endpoint + source';
    RAISE NOTICE '  UNDP   : provider + endpoint + source (si absent)';
END;
$$;
