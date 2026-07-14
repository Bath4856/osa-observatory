"""
OSA Observatory -- Bus de gouvernance événementielle (ADR-004)
api/services/governance_events.py

Point d'entrée unique de toute émission ET application d'événement de
gouvernance, pour tout domaine actuel ou futur (IDENTITY aujourd'hui ;
GOVERNANCE, REPOSITORY, METHODOLOGY, DATA, PUBLICATION, PRODUCT,
PARTNERSHIP -- candidats non démarrés, cf. ADR-004 §3). Ce module ne
contient jamais de logique métier de domaine -- il route uniquement.

Contient :
  - emit_governance_event()   : émission côté source (PREPROD)
  - register_domain_handler() : décorateur d'enregistrement, appliqué
    dans le module propre à chaque domaine (ex. api/routers/
    affiliation.py pour IDENTITY)
  - apply_governance_event()  : application côté cible (PROD),
    dispatchée vers le gestionnaire enregistré pour le domaine reçu

Remplace, pour toute nouvelle émission, la fonction emit_identity_event()
historique d'api/routers/affiliation.py -- laquelle n'est plus appelée
depuis la bascule du domaine IDENTITY (ADR-003 Phase 3) et devient
dormante par construction (plus aucune écriture nouvelle dans
mg.identity_events). Elle reste néanmoins présente dans le code, non
supprimée, conformément à la doctrine de coexistence jusqu'à la Phase 6
(ADR-003/ADR-004 §1).
"""
import os
import json
import hashlib
from sqlalchemy.orm import Session
from sqlalchemy import text

_DOMAIN_HANDLERS = {}


def register_domain_handler(domain_code: str):
    """
    Décorateur d'enregistrement -- à appliquer, dans le module du
    domaine concerné, sur la fonction unique qui contient toute la
    logique d'application des événements de ce domaine. Un seul point
    de vérité par domaine (ADR-004 §5 -- mutualisation, aucune
    duplication tolérée).

    Signature attendue du gestionnaire :
        handler(db: Session, event_type: str, object_uuid: str, payload: dict) -> dict
    """
    def decorator(fn):
        _DOMAIN_HANDLERS[domain_code] = fn
        return fn
    return decorator


def emit_governance_event(
    db: Session,
    domain_code: str,
    event_type: str,
    object_type: str,
    object_uuid,
    payload: dict,
    source_environment: str = "PREPROD",
    target_environment: str = "PROD",
):
    """
    Émet un événement de gouvernance dans mg.governance_events.

    N'a d'effet que si OSA_ENVIRONMENT correspond à source_environment
    (PREPROD par défaut) -- cohérent avec la doctrine ADR-001 : PREPROD
    est la référence organisationnelle, PROD ne reçoit que des
    décisions déjà validées, DEV est exclu de toute synchronisation.
    Vérifié à l'exécution, jamais en dur -- même code déployé sur les
    3 environnements.

    domain_code / event_type doivent correspondre à un enregistrement
    actif dans rf.event_types (contrainte FK composite) -- une erreur
    de frappe sur l'un des deux échoue à l'insertion, jamais
    silencieusement.
    """
    if os.getenv("OSA_ENVIRONMENT", "").upper() != source_environment:
        return

    payload_json = json.dumps(payload, sort_keys=True, default=str)
    payload_hash = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()

    db.execute(text("""
        INSERT INTO mg.governance_events
            (domain_code, event_type, object_type, object_uuid,
             source_environment, target_environment,
             payload, payload_hash, validated_at)
        VALUES
            (:domain_code, :event_type, :object_type, :object_uuid,
             :source_environment, :target_environment,
             CAST(:payload AS jsonb), :payload_hash, NOW())
    """), {
        "domain_code": domain_code,
        "event_type": event_type,
        "object_type": object_type,
        "object_uuid": str(object_uuid),
        "source_environment": source_environment,
        "target_environment": target_environment,
        "payload": payload_json,
        "payload_hash": payload_hash,
    })


def apply_governance_event(db: Session, domain_code: str, event_type: str, object_uuid: str, payload: dict) -> dict:
    """
    Applique un événement propagé -- dispatché vers le gestionnaire
    métier enregistré pour domain_code. Lève ValueError si aucun
    domaine correspondant n'est enregistré ; les routers appelants
    (ancien et nouveau endpoint) capturent cette exception pour
    retourner un 422 explicite, jamais un 500 silencieux.
    """
    handler = _DOMAIN_HANDLERS.get(domain_code)
    if handler is None:
        raise ValueError(f"Domaine non pris en charge : {domain_code}")
    return handler(db, event_type, object_uuid, payload)
