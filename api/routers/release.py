import time
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.middleware.telemetry import register_api_usage

router = APIRouter(prefix="/api/v2/release", tags=["Release"])


@router.get(
    "",
    summary="Release manifest",
    description="Returns the current P8 V2 release manifest with dataset and endpoint counts.",
)
async def get_release_manifest(db: Session = Depends(get_db)):
    t0 = time.time()

    row = db.execute(text("""
        SELECT * FROM pub.v_isa_release_manifest LIMIT 1
    """)).mappings().first()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_RELEASE", "/api/v2/release", "GET",
        "PUBLIC", 200, elapsed, 1
    )
    return dict(row) if row else {}
