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
    'a592c23b-423e-401f-aee4-a73fddce1129',
    'P7I-AMAR-GENECO',
    'GENECO_ANALYTICAL_INDEPENDENCE',
    encode(sha256('GENECO_ANALYTICAL_INDEPENDENCE|ma.v_p7i_amar_geneco_engine'::bytea), 'hex'),
    'MEDIUM',
    'NONE',
    0.00,
    'VIEW',
    'ma.v_p7i_amar_geneco_engine',
    'GENECO est construit exclusivement a partir de composantes issues du moteur P7I/AMAR (threat_score, strategic_risk_score, vulnerability_observed_score, stress_isa_delta) via la vue source commune ma.v_p7i_risk_source. Verification empirique de la definition de ma.v_p7i_amar_geneco_engine : aucun indicateur natif GENECO n''existe dans ma.computed_indicators (SELECT sur code ILIKE %GENECO% retourne 0 lignes). Le moteur GENECO calcule un risk_component = GREATEST(threat, strategic_risk, vulnerability, abs(stress_delta)) par pilier -- meme mecanisme que AMAR -- puis applique des pondérations thematiques specifiques (resource_capture_risk PMIN+PRES, logistics_enabling_risk PTRA+PMIL, institutional_capture_risk PGEO+PECO+PMON, civilian_exploitation_risk PHUM, narrative_weaponization_risk PNUM+PGEO) pour produire un geneco_exposure_score final. Le moteur est techniquement propre, coherent et explicable. Il n''y a pas de probleme de calcul au sens strict. La question est doctrinale : GENECO est-il concu comme un moteur autonome d''observation des economies de conflit (necessite des indicateurs natifs : extraction illicite, reseaux logistiques armes, taxation par groupes armes, etc.) ou comme un moteur thematique derive du diagnostic strategique P7I (situation actuelle) ? La reponse a cette question conditionne directement l''architecture du THR Trigger Audit (Regle 4, GAF #20) pour GENECO : si GENECO reste derive, le Trigger Audit couvre les deux modules depuis la source commune avec des piliers-cibles distincts (PMIN/PTRA/PMIL pour GENECO, PHUM/PMIL/PGEO pour AMAR). Si GENECO devient autonome, le Trigger Audit GENECO est a re-concevoir entierement depuis de nouvelles sources. Decision requise par le Conseil scientifique OSA avant tout sprint de mise en oeuvre de la Regle 4.',
    jsonb_build_object(
        'source_view', 'ma.v_p7i_amar_geneco_engine',
        'verified_at', '2026-06-22',
        'native_indicators_count', 0,
        'native_indicators_query', 'SELECT * FROM ma.computed_indicators WHERE code ILIKE ''%GENECO%'' -- retourne 0 lignes',
        'shared_source', 'ma.v_p7i_risk_source (identique a AMAR)',
        'risk_component_formula', 'GREATEST(threat_score, strategic_risk_score, vulnerability_observed_score, abs(stress_isa_delta))',
        'geneco_domains', jsonb_build_object(
            'resource_capture_risk', jsonb_build_array('PMIN x0.60', 'PRES x0.40'),
            'logistics_enabling_risk', jsonb_build_array('PTRA x0.65', 'PMIL x0.35'),
            'institutional_capture_risk', jsonb_build_array('PGEO x0.50', 'PECO x0.25', 'PMON x0.25'),
            'civilian_exploitation_risk', jsonb_build_array('PHUM x1.00'),
            'narrative_weaponization_risk', jsonb_build_array('PNUM x0.60', 'PGEO x0.40')
        ),
        'final_weights', jsonb_build_object(
            'resource_capture', 0.30,
            'logistics_enabling', 0.20,
            'institutional_capture', 0.25,
            'civilian_exploitation', 0.15,
            'narrative_weaponization', 0.10
        ),
        'doctrinal_question', 'Moteur derive du diagnostic strategique P7I (situation actuelle) ou moteur autonome d''observation des economies de conflit (indicateurs natifs) ?',
        'impact_on_gaf20_rule4', 'La reponse conditionne l''architecture du THR Trigger Audit pour GENECO -- piliers-cibles partages si derive, re-conception complete si autonome',
        'pillar_overlap_with_amar', jsonb_build_object(
            'pmil', 'present dans logistics_enabling_risk (GENECO) ET dans conflict_escalation (AMAR) -- signal double possible',
            'pgeo', 'present dans institutional_capture_risk ET narrative_weaponization_risk (GENECO) ET dans structural_fragility (AMAR)'
        ),
        'decision_required_from', 'Conseil scientifique OSA',
        'blocking', 'Implementation Regle 4 (THR Trigger Audit) pour GENECO'
    ),
    'OPEN'
)
RETURNING finding_id, finding_code, status;
