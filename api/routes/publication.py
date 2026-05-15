from fastapi import APIRouter
from api.db import fetch_all

router = APIRouter(prefix="/api/v1/publication", tags=["Publication Governance"])

@router.get("/open-data")
def get_open_data_catalog():
    return fetch_all("SELECT * FROM ma.v_isa_open_data_catalog ORDER BY dataset_code")

@router.get("/api-registry")
def get_api_registry():
    return fetch_all("SELECT * FROM ma.v_isa_api_registry ORDER BY endpoint_code")

@router.get("/governance")
def get_publication_governance():
    return fetch_all("SELECT * FROM ma.v_isa_publication_governance ORDER BY year DESC, country_iso3")
