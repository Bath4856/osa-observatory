INSERT INTO ops.audit_findings (
    audit_id,
    module,
    finding_code,
    finding_hash,
    severity,
    publication_impact,
    iprs_weight,
    object_type,
    object_code,
    description,
    raw_finding,
    status
) VALUES (
    'a592c23b-423e-401f-aee4-a73fddce1129',  -- cycle d'audit le plus recent (19 juin 2026, READY_FOR_PUBLICATION)
    'P7I-AMAR',
    'AMAR_THREAT_SIGNAL_OVERRIDDEN_BY_GREATEST',
    encode(sha256('AMAR_THREAT_SIGNAL_OVERRIDDEN_BY_GREATEST|v_p7i_amar_atrocity_precursor_engine'::bytea), 'hex'),
    'HIGH',           -- a confirmer/ajuster
    'CONDITIONAL',    -- a confirmer/ajuster
    2.00,             -- a confirmer/ajuster selon votre bareme IPRS
    'VIEW',
    'ma.v_p7i_amar_atrocity_precursor_engine',
    'Le calcul du score precurseur AMAR (effective_risk_score, ligne Correction B Sprint 12A) prend GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score) par pilier. Verification empirique sur COD (conflit actif 30 ans) vs CPV (pays stable) pour 2024 : strategic_risk_score remporte la comparaison GREATEST sur 8/10 piliers pour COD et 7/10 pour CPV, avec des plages de valeurs largement chevauchantes entre les deux pays (~0.17-0.49). threat_score, signal le plus directement lie aux evenements de conflit, reste systematiquement petit (0.01-0.17 pour la quasi-totalite des piliers COD, hors PENV) et ne remporte quasiment jamais la comparaison -- il est donc neutralise par construction dans la majorite des cas. Consequence observee : distribution AMAR 2024 tres compressee (52/54 pays en YELLOW, seuls SSD et SDN en ORANGE), un pays en conflit arme prolonge (COD, score 0.424) se retrouvant au niveau d''un Etat insulaire stable (STP 0.438, CPV ranking proche). Ceci est distinct de la rupture GREEN->YELLOW 2019-2020 deja documentee et justifiee dans rf.amar_known_breaks (id=1, Sprint12A) : cette derniere concerne une discontinuite temporelle ponctuelle liee a l''activation du moteur SWOT ; le present constat concerne le pouvoir discriminant du score sur la periode post-2020 elle-meme, non traite par la Correction B. GENECO partage probablement le meme schema architectural (cf. rf.amar_known_breaks id=2/3) mais n''a pas ete verifie empiriquement avec le meme niveau de detail -- a investiguer separement.',
    jsonb_build_object(
        'comparison_year', 2024,
        'countries_compared', jsonb_build_array('COD', 'CPV'),
        'cod_pillar_dominance', jsonb_build_object(
            'strategic_risk_wins', 8, 'threat_wins', 1, 'vulnerability_wins', 1, 'total_pillars', 10
        ),
        'cpv_pillar_dominance', jsonb_build_object(
            'strategic_risk_wins', 7, 'threat_wins', 0, 'vulnerability_wins', 3, 'total_pillars', 10
        ),
        'cod_threat_score_range', jsonb_build_array(0.0, 0.424),
        'cod_strategic_risk_range', jsonb_build_array(0.027, 0.474),
        'cpv_strategic_risk_range', jsonb_build_array(0.170, 0.493),
        'amar_2024_distribution', jsonb_build_object('ORANGE', 2, 'YELLOW', 52, 'GREEN', 0, 'RED', 0, 'BLACK', 0),
        'cod_amar_score_2024', 0.424,
        'cpv_amar_score_2024', 0.426,
        'related_known_break', 'rf.amar_known_breaks id=1 (Sprint12A, rupture 2019-2020, distincte de ce constat)',
        'source_view', 'ma.v_p7i_amar_atrocity_precursor_engine',
        'correction_applied', 'Sprint12A Correction B (24 mai 2026) -- traite la rupture temporelle, pas le pouvoir discriminant post-2020',
        'investigated_by', 'session diagnostic 21 juin 2026'
    ),
    'OPEN'
)
RETURNING finding_id, finding_hash, status;
