-- ============================================================
-- mg.analysis_review -- structure Regle/Preuve/Correction
-- 6 aout 2026
-- ============================================================
-- Correctif suite a la remarque de Theo : (1) le verdict doit suivre
-- une structure explicite Regle violee -> Preuve -> Correction proposee,
-- jamais un texte libre non structure ; (2) THEO ne doit jamais
-- reinterpreter les donnees lui-meme (ex. juger si un score est
-- "significatif"), seulement verifier si l'affirmation de SCRIBE est
-- explicitement etayee par une donnee fournie ou non.
--
-- review_comment_fr (texte libre) remplace par issues (jsonb, liste
-- structuree, vide si CONFORME).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE mg.analysis_review
    DROP COLUMN review_comment_fr;

ALTER TABLE mg.analysis_review
    ADD COLUMN issues jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMIT;

-- Verification post-execution
\d mg.analysis_review
