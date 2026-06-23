UPDATE ops.audit_findings
SET
    status = 'ORIENTED',
    description = description || E'\n\n--- Orientation methodologique : Comite technique et scientifique OSA (22 juin 2026) ---\nClarification doctrinale prealable : AMAR est un systeme d''alerte precurseur, non une mesure de trajectoire de souverainete. Cette distinction est structurante pour l''interpretation des resultats et pour toute correction methodologique.\n\nQuatre regles d''orientation validees par le Comite technique et scientifique OSA :\n\nRegle 1 -- WKN porte le contexte structurel. La dominance de WKN dans le score effectif (≈85%) est architecturalement justifiee pour un systeme d''alerte : WKN represente la vulnerabilite structurelle de fond, toujours presente, pour la majorite des pays dans la majorite des situations. Ce n''est pas un defaut.\n\nRegle 2 -- THR porte le signal exceptionnel. La rarete de THR (99,8% des valeurs <0.20 sur n=8100) n''est pas un defaut de calibration -- c''est la propriete qui lui confere sa valeur dans un systeme d''alerte. Un signal qui se declenche pour tout le monde tout le temps n''est pas un signal d''alerte.\n\nRegle 3 -- Ne jamais chercher a rendre WKN comparable a THR. Ils ne mesurent pas la meme chose (niveau structurel vs intensite de changement) et ne doivent pas etre calibres sur la meme echelle. Toute recalibration de THR vers l''echelle de WKN detruirait la nature exceptionnelle du signal.\n\nRegle 4 -- Instaurer un THR Trigger Audit annuel. Plutot que de faire competer THR dans une formule agregee, auditer annuellement les declenchements THR significatifs (seuil a definir, ordre de grandeur 0.20) et les traiter comme des signaux exceptionnels necessitant une revue humaine independante du score scalaire AMAR.\n\nReserve technique sur la Regle 4 (a preciser en implementation) : sous ce modele, un THR exceptionnel detecte au niveau d''un pilier (ex. SDN 2024, threat_score=1.000 sur PENV) risque d''etre dilue a travers les 6 domaines ponderes de la formule finale AMAR. Le THR Trigger Audit devrait probablement court-circuiter la formule agregee et produire une alerte directe, plutot qu''etre absorbe comme composante parmi d''autres. Le mecanisme exact de declenchement (seuil, piliers concernes, modalite d''alerte) est a definir par le Comite technique avant implementation.',
    raw_finding = raw_finding || jsonb_build_object(
        'orientation', jsonb_build_object(
            'oriented_at', '2026-06-22',
            'oriented_by', 'Comite technique et scientifique OSA',
            'doctrinal_clarification', 'AMAR est un systeme d''alerte precurseur, non une mesure de trajectoire de souverainete',
            'rules', jsonb_build_array(
                jsonb_build_object('id', 1, 'label', 'WKN porte le contexte structurel', 'detail', 'Dominance WKN ≈85% architecturalement justifiee pour un systeme d''alerte'),
                jsonb_build_object('id', 2, 'label', 'THR porte le signal exceptionnel', 'detail', 'Rarete THR (99.8% < 0.20) est une propriete, pas un defaut'),
                jsonb_build_object('id', 3, 'label', 'Ne jamais rendre WKN = THR', 'detail', 'Natures differentes (niveau vs intensite de changement), echelles incompatibles par construction'),
                jsonb_build_object('id', 4, 'label', 'THR Trigger Audit annuel', 'detail', 'Auditer les declenchements THR significatifs comme signaux exceptionnels, independamment du score scalaire')
            ),
            'implementation_reserve', jsonb_build_object(
                'rule', 4,
                'issue', 'THR exceptionnel (ex. SDN 2024 threat=1.000) risque d''etre dilue dans les 6 domaines ponderes -- le Trigger Audit devrait court-circuiter la formule agregee',
                'pending', 'Seuil THR, piliers concernes, modalite d''alerte directe -- a definir par Comite technique avant implementation'
            ),
            'key_empirical_evidence', jsonb_build_object(
                'sdn_2024_threat_score', 1.000,
                'sdn_2024_weakness_score', 0.000,
                'sdn_2024_strategic_attention_class', 'DIAGNOSTIC_MONITORING',
                'interpretation', 'Illustration directe : signal THR maximal absorbe sans declenchement d''alerte sous le modele actuel'
            )
        )
    ),
    updated_at = now()
WHERE finding_id = 20
RETURNING finding_id, module, status, updated_at;
