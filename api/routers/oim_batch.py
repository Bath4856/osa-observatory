"""
OSA Observatory -- OIM, pipeline de génération IA en masse (batch)
api/routers/oim_batch.py

Necessaire a l'echelle annoncee par Theo le 28 juillet 2026 : ~9000
generations/an (540 visions + ~2700 projets issus des plans d'actions
+ etudes de faisabilite/POC). En synchrone, se heurterait aux limites
de debit OpenAI et prendrait un temps considerable en serie -- l'API
Batch (50% moins cher, jusqu'a 24h de delai) est concue pour ce volume,
coherent avec le cycle annuel OIM (jamais en temps reel a la demande).

Portee : fournisseur OpenAI uniquement (format Batch API specifique).
Anthropic a sa propre API Batch (Message Batches), format different --
a construire separement si besoin futur.

Pipeline en 4 etapes :
1. Mise en file d'attente (queue-summary / queue-actions)
2. Soumission groupee (batch-jobs/submit) -- construit un fichier JSONL,
   l'envoie a OpenAI comme un seul job
3. Suivi de statut (batch-jobs/{id}/status)
4. Recuperation des resultats (batch-jobs/{id}/import-results) --
   applique chaque resultat a la bonne vision/action en base
"""
import json
import os
import tempfile
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate
from api.routers.osoa import SUMMARY_SYSTEM_PROMPT
from api.routers.oim_vision import ACTIONS_SYSTEM_PROMPT

try:
    import openai as _openai_sdk_batch
except ImportError:
    _openai_sdk_batch = None

router = APIRouter(
    prefix="/api/v2/oim",
    tags=["OIM - Génération IA en masse (batch)"],
)


def _openai_client():
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key or _openai_sdk_batch is None:
        raise HTTPException(status_code=503, detail={
            "fr": "OPENAI_API_KEY n'est pas configurée sur ce serveur -- requise pour le pipeline batch.",
            "en": "OPENAI_API_KEY is not configured on this server -- required for the batch pipeline.",
        })
    return _openai_sdk_batch.OpenAI(api_key=api_key)


# ── Etape 1 : mise en file d'attente ──────────────────────────────────────────

@router.post(
    "/deliverables/{deliverable_id}/queue-summary",
    summary="Mettre en file d'attente la génération du résumé exécutif (batch)",
    description="Alternative batch à generate-summary (osoa.py) -- réservé à ETUDE_OPPORTUNITE.",
)
def queue_summary(
    deliverable_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    deliverable = db.execute(
        text("SELECT id, deliverable_type, content FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})
    if deliverable["deliverable_type"] != "ETUDE_OPPORTUNITE":
        raise HTTPException(status_code=422, detail={
            "fr": "queue-summary réservé à ETUDE_OPPORTUNITE.",
            "en": "queue-summary reserved for ETUDE_OPPORTUNITE.",
        })

    row = db.execute(
        text("""
            INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
            VALUES ('VISION_SUMMARY', :target_id, CAST(:payload AS jsonb), :created_by)
            RETURNING id, generation_type, target_id, status, created_at::text
        """),
        {
            "target_id": deliverable_id,
            "payload": json.dumps(deliverable["content"], ensure_ascii=False),
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.post(
    "/deliverables/{deliverable_id}/queue-actions",
    summary="Mettre en file d'attente l'explosion en actions-projets (batch)",
    description="Alternative batch à generate-actions (oim_vision.py) -- réservé à PLAN_ACTION.",
)
def queue_actions(
    deliverable_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    deliverable = db.execute(
        text("SELECT id, deliverable_type, content FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})
    if deliverable["deliverable_type"] != "PLAN_ACTION":
        raise HTTPException(status_code=422, detail={
            "fr": "queue-actions réservé à PLAN_ACTION.",
            "en": "queue-actions reserved for PLAN_ACTION.",
        })

    row = db.execute(
        text("""
            INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
            VALUES ('PLAN_ACTION_EXPLOSION', :target_id, CAST(:payload AS jsonb), :created_by)
            RETURNING id, generation_type, target_id, status, created_at::text
        """),
        {
            "target_id": deliverable_id,
            "payload": json.dumps(deliverable["content"], ensure_ascii=False),
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.get("/batch-queue", summary="Lister la file d'attente de génération")
def list_queue(
    status: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, generation_type, target_id, status, batch_job_id, error_message, created_at::text
        FROM mg.ai_generation_queue WHERE 1=1
    """
    params: dict = {}
    if status:
        sql += " AND status = :status"
        params["status"] = status
    sql += " ORDER BY created_at"
    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


# ── Etape 2 : soumission groupee ──────────────────────────────────────────────

@router.post(
    "/batch-jobs/submit",
    summary="Soumettre toute la file d'attente comme un seul job OpenAI Batch",
    description="Construit un fichier JSONL avec toutes les demandes QUEUED, l'envoie en un seul job (50% moins cher, jusqu'à 24h).",
)
def submit_batch(
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    queued = db.execute(
        text("SELECT id, generation_type, request_payload FROM mg.ai_generation_queue WHERE status = 'QUEUED' ORDER BY id"),
    ).mappings().all()
    if not queued:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucune demande en file d'attente (status=QUEUED).",
            "en": "No requests in queue (status=QUEUED).",
        })

    client = _openai_client()

    lines = []
    for row in queued:
        system_prompt = SUMMARY_SYSTEM_PROMPT if row["generation_type"] == "VISION_SUMMARY" else ACTIONS_SYSTEM_PROMPT
        lines.append({
            "custom_id": f"queue-{row['id']}",
            "method": "POST",
            "url": "/v1/chat/completions",
            "body": {
                "model": "gpt-4o",
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": json.dumps(row["request_payload"], ensure_ascii=False)},
                ],
            },
        })

    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False) as f:
            for line in lines:
                f.write(json.dumps(line) + "\n")
            tmp_path = f.name

        with open(tmp_path, "rb") as f:
            uploaded_file = client.files.create(file=f, purpose="batch")

        batch = client.batches.create(
            input_file_id=uploaded_file.id,
            endpoint="/v1/chat/completions",
            completion_window="24h",
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la soumission du batch à OpenAI : {e}",
            "en": f"Failed to submit batch to OpenAI: {e}",
        })
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)

    job_row = db.execute(
        text("""
            INSERT INTO mg.ai_batch_jobs (provider, provider_batch_id, item_count, created_by)
            VALUES ('openai', :provider_batch_id, :item_count, :created_by)
            RETURNING id
        """),
        {"provider_batch_id": batch.id, "item_count": len(queued), "created_by": affiliate_id},
    ).mappings().first()

    queue_ids = [row["id"] for row in queued]
    db.execute(
        text("UPDATE mg.ai_generation_queue SET status = 'SUBMITTED', batch_job_id = :job_id, updated_at = NOW() WHERE id = ANY(:ids)"),
        {"job_id": job_row["id"], "ids": queue_ids},
    )
    db.commit()

    return {
        "batch_job_id": job_row["id"],
        "provider_batch_id": batch.id,
        "item_count": len(queued),
        "status": "SUBMITTED",
    }


# ── Etape 3 : suivi de statut ──────────────────────────────────────────────────

@router.get(
    "/batch-jobs/{batch_job_id}/status",
    summary="Vérifier le statut d'un job batch (interroge OpenAI en direct)",
)
def get_batch_status(batch_job_id: int, db: Session = Depends(get_db)):
    job = db.execute(
        text("SELECT id, provider_batch_id, status, item_count FROM mg.ai_batch_jobs WHERE id = :id"),
        {"id": batch_job_id},
    ).mappings().first()
    if not job:
        raise HTTPException(status_code=404, detail={"fr": "Job batch introuvable.", "en": "Batch job not found."})

    client = _openai_client()
    try:
        batch = client.batches.retrieve(job["provider_batch_id"])
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la vérification du statut auprès d'OpenAI : {e}",
            "en": f"Failed to check status with OpenAI: {e}",
        })

    status_map = {
        "validating": "IN_PROGRESS", "in_progress": "IN_PROGRESS", "finalizing": "IN_PROGRESS",
        "completed": "COMPLETED",
        "failed": "FAILED", "expired": "EXPIRED", "cancelling": "FAILED", "cancelled": "FAILED",
    }
    new_status = status_map.get(batch.status, "IN_PROGRESS")

    db.execute(
        text("""
            UPDATE mg.ai_batch_jobs SET status = :status,
                   completed_at = CASE WHEN :status = 'COMPLETED' THEN NOW() ELSE completed_at END
            WHERE id = :id
        """),
        {"status": new_status, "id": batch_job_id},
    )
    db.commit()

    return {
        "batch_job_id": batch_job_id,
        "provider_status_raw": batch.status,
        "status": new_status,
        "item_count": job["item_count"],
        "request_counts": getattr(batch, "request_counts", None).__dict__ if getattr(batch, "request_counts", None) else None,
    }


# ── Etape 4 : recuperation des resultats ──────────────────────────────────────

@router.post(
    "/batch-jobs/{batch_job_id}/import-results",
    summary="Récupérer les résultats d'un job terminé et les appliquer en base",
    description="Réservé aux jobs COMPLETED. Applique chaque résultat à la bonne vision (résumé) ou plan (actions).",
)
def import_batch_results(
    batch_job_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    job = db.execute(
        text("SELECT id, provider_batch_id, status FROM mg.ai_batch_jobs WHERE id = :id"),
        {"id": batch_job_id},
    ).mappings().first()
    if not job:
        raise HTTPException(status_code=404, detail={"fr": "Job batch introuvable.", "en": "Batch job not found."})

    client = _openai_client()
    try:
        batch = client.batches.retrieve(job["provider_batch_id"])
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la récupération du batch auprès d'OpenAI : {e}",
            "en": f"Failed to retrieve batch from OpenAI: {e}",
        })

    if batch.status != "completed":
        raise HTTPException(status_code=422, detail={
            "fr": f"Le job n'est pas encore terminé côté OpenAI (statut réel : {batch.status}).",
            "en": f"The job is not yet completed on OpenAI's side (real status: {batch.status}).",
        })
    if not batch.output_file_id:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun fichier de résultats disponible.",
            "en": "No results file available.",
        })

    try:
        content = client.files.content(batch.output_file_id).text
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec du téléchargement des résultats : {e}",
            "en": f"Failed to download results: {e}",
        })

    imported, failed = 0, 0
    for line in content.strip().split("\n"):
        if not line:
            continue
        result = json.loads(line)
        custom_id = result.get("custom_id", "")
        queue_id = int(custom_id.replace("queue-", "")) if custom_id.startswith("queue-") else None
        if queue_id is None:
            continue

        queue_row = db.execute(
            text("SELECT id, generation_type, target_id FROM mg.ai_generation_queue WHERE id = :id"),
            {"id": queue_id},
        ).mappings().first()
        if not queue_row:
            continue

        if result.get("error") or result.get("response", {}).get("status_code") != 200:
            db.execute(
                text("UPDATE mg.ai_generation_queue SET status = 'FAILED', error_message = :err, updated_at = NOW() WHERE id = :id"),
                {"err": json.dumps(result.get("error") or result.get("response")), "id": queue_id},
            )
            failed += 1
            continue

        try:
            raw_content = result["response"]["body"]["choices"][0]["message"]["content"]
            parsed = json.loads(raw_content)

            if queue_row["generation_type"] == "VISION_SUMMARY":
                db.execute(
                    text("""
                        UPDATE osoa.strategic_deliverables
                        SET public_summary_fr = :fr, public_summary_en = :en, summary_status = 'AI_DRAFTED'
                        WHERE id = :id
                    """),
                    {"fr": parsed["summary_fr"], "en": parsed["summary_en"], "id": queue_row["target_id"]},
                )
            else:  # PLAN_ACTION_EXPLOSION
                for action in parsed["actions"]:
                    db.execute(
                        text("""
                            INSERT INTO mg.plan_action_projects
                                (deliverable_id, action_name_fr, action_name_en, action_description_fr, action_description_en, created_by)
                            VALUES (:deliverable_id, :name_fr, :name_en, :desc_fr, :desc_en, :created_by)
                        """),
                        {
                            "deliverable_id": queue_row["target_id"],
                            "name_fr": action["name_fr"], "name_en": action.get("name_en"),
                            "desc_fr": action["description_fr"], "desc_en": action.get("description_en"),
                            "created_by": int(payload["sub"]),
                        },
                    )

            db.execute(
                text("UPDATE mg.ai_generation_queue SET status = 'COMPLETED', updated_at = NOW() WHERE id = :id"),
                {"id": queue_id},
            )
            imported += 1
        except Exception as e:
            db.execute(
                text("UPDATE mg.ai_generation_queue SET status = 'FAILED', error_message = :err, updated_at = NOW() WHERE id = :id"),
                {"err": str(e), "id": queue_id},
            )
            failed += 1

    db.commit()

    return {"batch_job_id": batch_job_id, "imported": imported, "failed": failed}
