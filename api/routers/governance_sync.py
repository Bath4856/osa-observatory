"""
OSA Observatory -- Bus de gouvernance événementielle (ADR-004)
api/routers/governance_sync.py

Router générique de synchronisation -- point d'entrée cible unique
pour tout domaine, appelé exclusivement par governance_synchronizer.py.

Coexiste avec POST /api/v1/affiliation/sync/apply-event (ADR-001,
appelé par identity_synchronizer.py) jusqu'à la Phase 6 du plan de
migration (ADR-003) -- les deux endpoints partagent la même logique
métier mutualisée via api.services.governance_events.
apply_governance_event(), jamais dupliquée (ADR-004 §5).
"""
import os
from fastapi import APIRouter, HTTPException, Request, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from api.db import get_db
from api.services.governance_events import apply_governance_event

router = APIRouter(
    prefix="/api/v1/sync",
    tags=["Bus de gouvernance OSA"],
)

# Même secret partagé que l'ancien mécanisme -- aucune rotation requise
# par cette généralisation (ADR-004, décision du 14 juillet 2026).
SYNC_SHARED_SECRET = os.getenv("IDENTITY_SYNC_SECRET", "")


class GenericSyncEventPayload(BaseModel):
    domain_code: str
    event_type: str
    object_uuid: str
    payload: dict


@router.post(
    "/apply-event",
    summary="[Interne] Appliquer un événement de gouvernance propagé (générique, tous domaines)",
    description=(
        "Réservé au service governance_synchronizer.py -- protégé par secret partagé, "
        "pas une session utilisateur. Dispatché par domain_code vers le gestionnaire "
        "métier enregistré pour ce domaine (cf. api.services.governance_events). "
        "Aujourd'hui, seul IDENTITY est enregistré -- tout autre domain_code retourne "
        "un 422 explicite, jamais un traitement silencieux."
    ),
)
def apply_event_generic(body: GenericSyncEventPayload, request: Request, db: Session = Depends(get_db)):
    if not SYNC_SHARED_SECRET or request.headers.get("X-Sync-Secret") != SYNC_SHARED_SECRET:
        raise HTTPException(status_code=403, detail="Accès refusé.")

    try:
        return apply_governance_event(db, body.domain_code, body.event_type, body.object_uuid, body.payload)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
