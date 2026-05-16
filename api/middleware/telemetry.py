import asyncio
from sqlalchemy import text
from api.db import SessionLocal


def _write_usage_sync(
    endpoint_code: str,
    api_path: str,
    method: str,
    access_class: str,
    response_status: int,
    response_time_ms: float,
    rows_returned: int,
) -> None:
    """
    Écriture synchrone dans mg.api_usage_registry.
    Appelée via asyncio.to_thread pour compatibilité avec FastAPI async.
    Corrigé : db.close() dans finally.
    """
    db = SessionLocal()
    try:
        query = text("""
            INSERT INTO mg.api_usage_registry (
                endpoint_code,
                api_path,
                http_method,
                access_class,
                response_status,
                response_time_ms,
                rows_returned,
                release_code,
                semantic_version
            )
            SELECT
                :endpoint_code,
                :api_path,
                :method,
                :access_class,
                :response_status,
                :response_time_ms,
                :rows_returned,
                release_code,
                semantic_version
            FROM pub.v_isa_release_manifest
            LIMIT 1
        """)
        db.execute(query, {
            "endpoint_code":   endpoint_code,
            "api_path":        api_path,
            "method":          method,
            "access_class":    access_class,
            "response_status": response_status,
            "response_time_ms":response_time_ms,
            "rows_returned":   rows_returned,
        })
        db.commit()
    except Exception:
        db.rollback()
        # Erreur telemetry non bloquante — on ne fait pas remonter
        pass
    finally:
        db.close()


async def register_api_usage(
    endpoint_code: str,
    api_path: str,
    method: str,
    access_class: str,
    response_status: int,
    response_time_ms: float,
    rows_returned: int,
) -> None:
    """
    Enregistrement asynchrone de l'usage API.
    Utilise asyncio.to_thread pour ne pas bloquer la boucle événementielle.
    """
    await asyncio.to_thread(
        _write_usage_sync,
        endpoint_code,
        api_path,
        method,
        access_class,
        response_status,
        response_time_ms,
        rows_returned,
    )
