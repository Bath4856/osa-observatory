-- ================================================================
-- CONFIGURATION ANNUELLE DU PIPELINE ISA
-- ma.isa_config
-- OSA Observatory -- Mai 2026
-- ================================================================

CREATE TABLE ma.isa_config (
    param       VARCHAR(50)  NOT NULL,
    value       VARCHAR(50)  NOT NULL,
    description TEXT,
    updated_by  VARCHAR(100) DEFAULT 'OSA-team',
    updated_at  TIMESTAMP    DEFAULT now(),
    PRIMARY KEY (param)
);

COMMENT ON TABLE ma.isa_config IS
'Parametres de configuration du pipeline ISA. Mise a jour annuelle avant chaque cycle de calcul. annee_cible = millesime ISA en cours. annee_pub = annee de publication correspondante (N+1).';

INSERT INTO ma.isa_config (param, value, description) VALUES
    ('annee_cible', '2024',
     'Millesime ISA en cours de calcul — donnees collectees sur cette annee'),
    ('annee_pub',   '2025',
     'Annee de publication ISA correspondante (N+1)'),
    ('serie_debut', '2010',
     'Debut de la serie historique — bornes de normalisation L2'),
    ('serie_fin',   '2024',
     'Fin de la serie historique courante — s etend chaque annee'),
    ('weakness_debut', '2020',
     'Premier millesime de calcul WEAKNESS — debut serie ISA'),
    ('threat_debut', '2021',
     'Premier millesime de calcul THREAT — necessite 2 points temporels'),
    ('method_version_id', '1',
     'Version methodologique active — minmax / weighted_sum / equal');

-- Verification
SELECT param, value, description FROM ma.isa_config ORDER BY param;