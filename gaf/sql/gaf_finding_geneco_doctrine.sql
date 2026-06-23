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
    'GENECO_OBSERVATIONAL_DOCTRINE_ALIGNMENT',
    encode(sha256('GENECO_OBSERVATIONAL_DOCTRINE_ALIGNMENT|P7I-AMAR-GENECO'::bytea), 'hex'),
    'MEDIUM',
    'NONE',
    0.00,
    'MODULE',
    'P7I-AMAR-GENECO',
    'Premier GAF doctrinal majeur de GENECO. Le moteur GENECO est actuellement construit exclusivement a partir de composantes issues du moteur P7I/AMAR (threat_score, strategic_risk_score, vulnerability_observed_score, stress_isa_delta), elles-memes issues de traitements analytiques prealables. GENECO n''est donc pas alimente par des observations directes de mecanismes economiques de conflit mais par des signaux de risque deja interpretes. Ecart doctrinal identifie : la doctrine fondatrice OSA repose sur Observation -> Mesure -> Publication. La chaine actuelle de GENECO est Observation -> ISA -> P7I -> AMAR -> GENECO, qui s''eloigne progressivement de l''observation directe. Ce finding ne remet pas en cause les calculs, les donnees ou les resultats publies. Il ne remet pas en cause les publications historiques. Il interroge la conformite du produit a la philosophie fondatrice de l''OSA : observer avant d''interpreter. Impact publication : nul. Impact scientifique : eleve a moyen terme (risque de confusion entre observation et perception, difficulte de differenciation scientifique AMAR/GENECO, perte de coherence a mesure que les indicateurs transversaux observes se developperont). Cause racine documentee : GENECO a ete concu comme extension analytique de P7I afin d''assurer une couverture immediate de tous les pays -- choix delibere de disponibilite avant autonomie observationnelle. Orientation validee : transition progressive GENECO v1 (moteur derive P7I, situation actuelle) -> GENECO v2 (moteur hybride P7I + observations transversales) -> GENECO v3 (moteur principalement alimente par observations directes). Socle de transition : indicateurs transversaux conformes a la doctrine OSA (PMIN_VALUE_CAPTURE, PMIN_VALUE_LEAKAGE, PMIN_SMUGGLING_SIGNAL, ECO_PUBLIC_LEAKAGE, ECO_TAX_EFFICIENCY, PNUM_DIGITAL_CAPTURE, PMON_RESERVE_CAPTURE, futurs PTRA et PENV). Distinct du finding_id=21 (GENECO_ANALYTICAL_INDEPENDENCE, impact technique sur Regle 4 THR Trigger Audit) : le present finding est de nature doctrinale et scientifique, pas technique.',
    jsonb_build_object(
        'gaf_reference', 'GAF-GENECO-DOCTRINE-001',
        'classification', jsonb_build_object(
            'domaine', 'Doctrine scientifique',
            'produit', 'GENECO',
            'type', 'Alignement methodologique',
            'gravite', 'MODERATE',
            'impact_publication', 'NON BLOQUANT',
            'impact_scientifique', 'ELEVE',
            'impact_technique', 'FAIBLE'
        ),
        'dependency_chain', jsonb_build_array('Observation', 'ISA', 'P7I', 'AMAR', 'GENECO'),
        'doctrinal_principle', 'Observation -> Mesure -> Publication',
        'current_chain', 'Observation -> Interpretation -> Reinterpretation -> Publication',
        'impact_assessment', jsonb_build_object(
            'impact_faible', jsonb_build_array('aucun impact ISA', 'aucun impact publications existantes', 'aucun impact calculs actuels'),
            'impact_modere', jsonb_build_array('risque dilution doctrine Observation d''abord', 'difficulte differenciation scientifique AMAR/GENECO', 'perte coherence avec developpement futurs indicateurs transversaux')
        ),
        'evolution_roadmap', jsonb_build_object(
            'v1', 'Moteur derive de P7I (situation actuelle) -- valide pour publications en cours',
            'v2', 'Moteur hybride P7I + observations transversales',
            'v3', 'Moteur principalement alimente par observations directes des mecanismes economiques'
        ),
        'transition_indicators', jsonb_build_array(
            'PMIN_VALUE_CAPTURE', 'PMIN_VALUE_LEAKAGE', 'PMIN_SMUGGLING_SIGNAL',
            'ECO_PUBLIC_LEAKAGE', 'ECO_TAX_EFFICIENCY', 'PNUM_DIGITAL_CAPTURE',
            'PMON_RESERVE_CAPTURE', 'futurs PTRA', 'futurs PENV'
        ),
        'decision', 'ACCEPTED WITH EVOLUTION PLAN',
        'related_finding', jsonb_build_object(
            'finding_id', 21,
            'finding_code', 'GENECO_ANALYTICAL_INDEPENDENCE',
            'distinction', 'finding_id=21 est technique (impact sur Regle 4 THR Trigger Audit) -- ce finding est doctrinal et scientifique'
        ),
        'oriented_by', 'Conseil scientifique OSA',
        'oriented_at', '2026-06-22'
    ),
    'ORIENTED'
)
RETURNING finding_id, finding_code, status;
