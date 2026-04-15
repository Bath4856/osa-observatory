-- PATCH PRES META — SOV_PRES + GPRES
-- Complète patch_pres_pilier.sql
BEGIN;
INSERT INTO rf.meta_indicators (meta_code, name_fr, name_en, pillar_code, description) VALUES
('SOV_PRES', 'Indice souveraineté ressources stratégiques', 'Strategic Resources Sovereignty Index', 'PRES', 'Mesure la capacité à produire et sécuriser énergie et eau')
ON CONFLICT (meta_code) DO NOTHING;
INSERT INTO mm.indicator_groups (code, name, pillar_code, display_order) VALUES
('GPRES', 'Groupe indicateurs ressources stratégiques', 'PRES', 9)
ON CONFLICT (code) DO NOTHING;
DO $$ DECLARE v_meta INTEGER; v_grp INTEGER;
BEGIN
SELECT COUNT(*) INTO v_meta FROM rf.meta_indicators WHERE meta_code='SOV_PRES';
SELECT COUNT(*) INTO v_grp  FROM mm.indicator_groups WHERE code='GPRES';
RAISE NOTICE 'PATCH PRES META — SOV_PRES:% GPRES:%', v_meta, v_grp;
IF v_meta<>1 OR v_grp<>1 THEN
RAISE EXCEPTION 'PATCH PRES META echoue';
END IF; END $$;
COMMIT;
