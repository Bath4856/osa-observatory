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
1. Mise en file d'attente (queue-analyses / queue-reviews / queue-summary
   / queue-actions)
2. Soumission groupee (batch-jobs/submit) -- construit un fichier JSONL,
   l'envoie a OpenAI comme un seul job
3. Suivi de statut (batch-jobs/{id}/status)
4. Recuperation des resultats (batch-jobs/{id}/import-results) --
   applique chaque resultat a la bonne vision/action/revue en base

AJOUT DU 6 AOUT 2026 (apres-midi) : THEO (agent reviseur) devient
batchable, sur le meme patron que SCRIBE -- necessaire pour un vrai
test grandeur nature a l'echelle des 540 visions/an (Theo : "sans
cela le calendrier de la revue ne serait pas representatif de la
procedure annuelle reelle"). queue-reviews (par vision) et
queue-all-pending-reviews (toutes visions confondues, pour lancer le
test a l'echelle en un seul appel) mettent en file une revue par
brouillon AI_DRAFTED -- meme mecanisme de reconstruction du prompt
(schema + vocabulaire controle + regles specifiques) que pour
queue-analyses, aucune duplication.
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
from api.routers.osoa import SUMMARY_SYSTEM_PROMPT, METHOD_MODELS, ContentAnalysisReview, _build_opportunity_evidence
from api.routers.oim_vision import ACTIONS_SYSTEM_PROMPT
from api.routers.oim_analysis_gen import (
    PRIMARY_METHODS, PRIMARY_ANALYSIS_SYSTEM_PROMPT, MULTICRITERE_SPECIFIC_RULE,
    BOUNDED_SCORE_FIELDS, _extract_controlled_vocabulary, _get_pillar_data_snapshot,
    REVIEWER_SYSTEM_PROMPT, ANALYSIS_TRIGGER_MESSAGE, REVIEW_TRIGGER_MESSAGE,
)

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


def _build_review_method_rules(method: str) -> str:
    if method == "MULTICRITERE":
        return "\nRegle specifique MULTICRITERE qui etait imposee a SCRIBE :\n" + MULTICRITERE_SPECIFIC_RULE.format(bounded_fields=", ".join(BOUNDED_SCORE_FIELDS))
    return ""


# ── Etape 1 : mise en file d'attente ──────────────────────────────────────────

@router.post(
    "/visions/{vision_id}/queue-analyses",
    summary="Mettre en file d'attente les 9 analyses primaires d'une vision (batch)",
    description="Alternative batch à generate-analysis-drafts (oim_analysis_gen.py) -- une entrée par méthode (9 au total), snapshot ISA+POA réel calculé une seule fois et réutilisé.",
)
def queue_primary_analyses(
    vision_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    vision = db.execute(
        text("SELECT id, country_iso3, pillar_code, year FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": vision_id},
    ).mappings().first()
    if not vision:
        raise HTTPException(status_code=404, detail={"fr": "Vision introuvable.", "en": "Vision not found."})

    snapshot = _get_pillar_data_snapshot(db, vision["country_iso3"], vision["pillar_code"], vision["year"])
    if not snapshot:
        raise HTTPException(status_code=422, detail={
            "fr": f"Aucune donnée ISA observée pour {vision['country_iso3']}/{vision['pillar_code']}/{vision['year']} -- mise en file impossible sans donnée réelle.",
            "en": f"No observed ISA data for {vision['country_iso3']}/{vision['pillar_code']}/{vision['year']} -- queuing impossible without real data.",
        })

    created = []
    for method in PRIMARY_METHODS:
        row = db.execute(
            text("""
                INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
                VALUES ('PRIMARY_ANALYSIS', :target_id, CAST(:payload AS jsonb), :created_by)
                RETURNING id, generation_type, target_id, status, created_at::text
            """),
            {
                "target_id": vision_id,
                "payload": json.dumps({"method": method, "snapshot": snapshot}, ensure_ascii=False, default=str),
                "created_by": affiliate_id,
            },
        ).mappings().first()
        created.append(dict(row))

    db.commit()
    return {"count": len(created), "items": created}


@router.post(
    "/visions/queue-all-pending-analyses",
    summary="Mettre en file d'attente les 9 analyses primaires pour TOUTES les visions sans brouillon existant (batch à l'échelle)",
    description="Utile pour un test à grande échelle -- évite d'appeler queue-analyses vision par vision. Filtre optionnel par année.",
)
def queue_all_pending_analyses(
    year: Optional[int] = Query(default=None),
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    sql = """
        SELECT v.id, v.country_iso3, v.pillar_code, v.year
        FROM mg.pillar_strategic_vision v
        WHERE NOT EXISTS (
            SELECT 1 FROM mg.pillar_analysis_drafts pad WHERE pad.vision_id = v.id
        )
    """
    params: dict = {}
    if year is not None:
        sql += " AND v.year = :year"
        params["year"] = year
    sql += " ORDER BY v.country_iso3, v.pillar_code"

    visions = db.execute(text(sql), params).mappings().all()
    if not visions:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucune vision sans analyse à mettre en file.",
            "en": "No vision without analysis to queue.",
        })

    queued_count = 0
    visions_skipped_no_data = []
    for v in visions:
        snapshot = _get_pillar_data_snapshot(db, v["country_iso3"], v["pillar_code"], v["year"])
        if not snapshot:
            visions_skipped_no_data.append(v["id"])
            continue
        for method in PRIMARY_METHODS:
            db.execute(
                text("""
                    INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
                    VALUES ('PRIMARY_ANALYSIS', :target_id, CAST(:payload AS jsonb), :created_by)
                """),
                {
                    "target_id": v["id"],
                    "payload": json.dumps({"method": method, "snapshot": snapshot}, ensure_ascii=False, default=str),
                    "created_by": affiliate_id,
                },
            )
            queued_count += 1

    db.commit()
    return {
        "queued_count": queued_count,
        "visions_processed": len(visions) - len(visions_skipped_no_data),
        "visions_skipped_no_data": visions_skipped_no_data,
    }


@router.post(
    "/visions/{vision_id}/queue-reviews",
    summary="Mettre en file d'attente la revue THEO de toutes les analyses AI_DRAFTED d'une vision (batch)",
    description="Une entrée par brouillon AI_DRAFTED de la vision. Même reconstruction de prompt (schéma+vocabulaire+règles spécifiques) que review_analysis_draft (oim_analysis_gen.py), aucune duplication.",
)
def queue_analysis_reviews(
    vision_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    vision = db.execute(
        text("SELECT id, country_iso3, pillar_code, year FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": vision_id},
    ).mappings().first()
    if not vision:
        raise HTTPException(status_code=404, detail={"fr": "Vision introuvable.", "en": "Vision not found."})

    drafts = db.execute(
        text("SELECT id, method, content FROM mg.pillar_analysis_drafts WHERE vision_id = :vision_id AND status = 'AI_DRAFTED'"),
        {"vision_id": vision_id},
    ).mappings().all()
    if not drafts:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun brouillon AI_DRAFTED pour cette vision.",
            "en": "No AI_DRAFTED draft for this vision.",
        })

    snapshot = _get_pillar_data_snapshot(db, vision["country_iso3"], vision["pillar_code"], vision["year"])

    created = []
    for d in drafts:
        row = db.execute(
            text("""
                INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
                VALUES ('ANALYSIS_REVIEW', :target_id, CAST(:payload AS jsonb), :created_by)
                RETURNING id, generation_type, target_id, status, created_at::text
            """),
            {
                "target_id": d["id"],
                "payload": json.dumps(
                    {"method": d["method"], "snapshot": snapshot, "analysis_content": d["content"]},
                    ensure_ascii=False, default=str,
                ),
                "created_by": affiliate_id,
            },
        ).mappings().first()
        created.append(dict(row))

    db.commit()
    return {"count": len(created), "items": created}


@router.post(
    "/analysis-drafts/queue-all-pending-reviews",
    summary="Mettre en file d'attente la revue THEO de TOUTES les analyses AI_DRAFTED du système (toutes visions confondues)",
    description="Utile pour un test à grande échelle -- évite d'appeler queue-reviews vision par vision. Snapshot mis en cache par (pays, pilier, année) pour éviter de le recalculer 9 fois par vision.",
)
def queue_all_pending_reviews(
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    drafts = db.execute(
        text("""
            SELECT pad.id, pad.method, pad.content, pad.vision_id,
                   v.country_iso3, v.pillar_code, v.year
            FROM mg.pillar_analysis_drafts pad
            JOIN mg.pillar_strategic_vision v ON v.id = pad.vision_id
            WHERE pad.status = 'AI_DRAFTED'
        """),
    ).mappings().all()
    if not drafts:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun brouillon AI_DRAFTED dans le système.",
            "en": "No AI_DRAFTED draft in the system.",
        })

    snapshot_cache = {}
    created_ids = []
    for d in drafts:
        cache_key = (d["country_iso3"], d["pillar_code"], d["year"])
        if cache_key not in snapshot_cache:
            snapshot_cache[cache_key] = _get_pillar_data_snapshot(db, d["country_iso3"], d["pillar_code"], d["year"])
        snapshot = snapshot_cache[cache_key]

        row = db.execute(
            text("""
                INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
                VALUES ('ANALYSIS_REVIEW', :target_id, CAST(:payload AS jsonb), :created_by)
                RETURNING id
            """),
            {
                "target_id": d["id"],
                "payload": json.dumps(
                    {"method": d["method"], "snapshot": snapshot, "analysis_content": d["content"]},
                    ensure_ascii=False, default=str,
                ),
                "created_by": affiliate_id,
            },
        ).mappings().first()
        created_ids.append(row["id"])

    db.commit()
    return {"count": len(created_ids), "queue_ids": created_ids}


def _fetch_lever_for_vision(db: Session, vision_id: int) -> dict:
    """Meme garde-fou levier que partout ailleurs -- factorise ici pour
    eviter de le dupliquer entre queue_summary et queue_all_pending_summaries."""
    pourquoi_analysis = db.execute(
        text("""
            SELECT id FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = '5_POURQUOI'
            ORDER BY created_at DESC LIMIT 1
        """),
        {"vision_id": vision_id},
    ).mappings().first()
    if not pourquoi_analysis:
        return None
    return db.execute(
        text("""
            SELECT sl.lever_code, sl.label_fr, sl.description_fr
            FROM mg.lever_evidence le
            JOIN rf.strategic_levers sl ON sl.lever_code = le.lever_code
            WHERE le.analysis_id = :analysis_id
            ORDER BY le.relevance_weight DESC LIMIT 1
        """),
        {"analysis_id": pourquoi_analysis["id"]},
    ).mappings().first()


@router.post(
    "/deliverables/{deliverable_id}/queue-summary",
    summary="Mettre en file d'attente la génération du résumé exécutif (batch)",
    description="Alternative batch à generate-summary (osoa.py) -- réservé à ETUDE_OPPORTUNITE. Utilise le vrai paquet de preuves OpportunityEvidence, exige un levier promu.",
)
def queue_summary(
    deliverable_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    deliverable = db.execute(
        text("SELECT id, vision_id, deliverable_type FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})
    if deliverable["deliverable_type"] != "ETUDE_OPPORTUNITE":
        raise HTTPException(status_code=422, detail={
            "fr": "queue-summary réservé à ETUDE_OPPORTUNITE.",
            "en": "queue-summary reserved for ETUDE_OPPORTUNITE.",
        })

    lever = _fetch_lever_for_vision(db, deliverable["vision_id"])
    if not lever:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun levier stratégique promu pour cette vision.",
            "en": "No promoted strategic lever for this vision.",
        })

    evidence = _build_opportunity_evidence(db, deliverable["vision_id"])
    evidence["levier_strategique"] = {
        "lever_code": lever["lever_code"], "label_fr": lever["label_fr"], "description_fr": lever["description_fr"],
    }

    row = db.execute(
        text("""
            INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
            VALUES ('VISION_SUMMARY', :target_id, CAST(:payload AS jsonb), :created_by)
            RETURNING id, generation_type, target_id, status, created_at::text
        """),
        {
            "target_id": deliverable_id,
            "payload": json.dumps(evidence, ensure_ascii=False, default=str),
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.post(
    "/deliverables/queue-all-pending-summaries",
    summary="Mettre en file d'attente les résumés exécutifs pour TOUS les livrables ETUDE_OPPORTUNITE sans résumé (batch à l'échelle)",
    description="Utile pour lancer la campagne complète (540 résumés) -- ignore silencieusement les visions sans levier promu (comptees a part dans la reponse).",
)
def queue_all_pending_summaries(
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    deliverables = db.execute(
        text("""
            SELECT id, vision_id FROM osoa.strategic_deliverables
            WHERE deliverable_type = 'ETUDE_OPPORTUNITE' AND public_summary_fr IS NULL
        """),
    ).mappings().all()
    if not deliverables:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun livrable ETUDE_OPPORTUNITE sans résumé.",
            "en": "No ETUDE_OPPORTUNITE deliverable without a summary.",
        })

    queued_count = 0
    skipped_no_lever = []
    for d in deliverables:
        lever = _fetch_lever_for_vision(db, d["vision_id"])
        if not lever:
            skipped_no_lever.append(d["id"])
            continue
        try:
            evidence = _build_opportunity_evidence(db, d["vision_id"])
        except HTTPException:
            skipped_no_lever.append(d["id"])
            continue
        evidence["levier_strategique"] = {
            "lever_code": lever["lever_code"], "label_fr": lever["label_fr"], "description_fr": lever["description_fr"],
        }
        db.execute(
            text("""
                INSERT INTO mg.ai_generation_queue (generation_type, target_id, request_payload, created_by)
                VALUES ('VISION_SUMMARY', :target_id, CAST(:payload AS jsonb), :created_by)
            """),
            {
                "target_id": d["id"],
                "payload": json.dumps(evidence, ensure_ascii=False, default=str),
                "created_by": affiliate_id,
            },
        )
        queued_count += 1

    db.commit()
    return {
        "queued_count": queued_count,
        "deliverables_skipped_no_lever_or_evidence": skipped_no_lever,
    }


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
    summary="Soumettre la file d'attente comme un job OpenAI Batch (avec découpage en lots optionnel)",
    description="Construit un fichier JSONL avec les demandes QUEUED les plus anciennes, dans la limite de chunk_size (defaut 60, mesure reelle : ~1000 tokens/element, plafond OpenAI de 90k jetons enqueued sur tout le compte -- marge de securite incluse). Les elements restants demeurent QUEUED pour un lot suivant.",
)
def submit_batch(
    chunk_size: int = Query(default=60, ge=1, le=500),
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    queued = db.execute(
        text("SELECT id, generation_type, request_payload FROM mg.ai_generation_queue WHERE status = 'QUEUED' ORDER BY id LIMIT :chunk_size"),
        {"chunk_size": chunk_size},
    ).mappings().all()
    if not queued:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucune demande en file d'attente (status=QUEUED).",
            "en": "No requests in queue (status=QUEUED).",
        })

    client = _openai_client()

    lines = []
    for row in queued:
        if row["generation_type"] == "VISION_SUMMARY":
            system_prompt = SUMMARY_SYSTEM_PROMPT
            user_content = json.dumps(row["request_payload"], ensure_ascii=False)
        elif row["generation_type"] == "PLAN_ACTION_EXPLOSION":
            system_prompt = ACTIONS_SYSTEM_PROMPT
            user_content = json.dumps(row["request_payload"], ensure_ascii=False)
        elif row["generation_type"] == "PRIMARY_ANALYSIS":
            method = row["request_payload"]["method"]
            snapshot = row["request_payload"]["snapshot"]
            model_cls = METHOD_MODELS[method]
            schema = model_cls.model_json_schema()
            schema_json = json.dumps(schema, ensure_ascii=False)
            vocabulary = _extract_controlled_vocabulary(schema)
            method_specific_rules = ""
            if method == "MULTICRITERE":
                method_specific_rules = MULTICRITERE_SPECIFIC_RULE.format(bounded_fields=", ".join(BOUNDED_SCORE_FIELDS))
            snapshot_json = json.dumps(snapshot, ensure_ascii=False)
            system_prompt = PRIMARY_ANALYSIS_SYSTEM_PROMPT.format(
                method=method, data_snapshot=snapshot_json, vocabulary=vocabulary,
                schema=schema_json, method_specific_rules=method_specific_rules,
            )
            user_content = ANALYSIS_TRIGGER_MESSAGE
        elif row["generation_type"] == "ANALYSIS_REVIEW":
            method = row["request_payload"]["method"]
            snapshot = row["request_payload"]["snapshot"]
            analysis_content = row["request_payload"]["analysis_content"]
            model_cls = METHOD_MODELS[method]
            schema = model_cls.model_json_schema()
            schema_json = json.dumps(schema, ensure_ascii=False)
            vocabulary = _extract_controlled_vocabulary(schema)
            method_specific_rules = _build_review_method_rules(method)
            snapshot_json = json.dumps(snapshot, ensure_ascii=False, default=str)
            content_json = json.dumps(analysis_content, ensure_ascii=False, default=str)
            system_prompt = REVIEWER_SYSTEM_PROMPT.format(
                data_snapshot=snapshot_json, method=method, analysis_content=content_json,
                schema=schema_json, vocabulary=vocabulary, method_specific_rules=method_specific_rules,
            )
            user_content = REVIEW_TRIGGER_MESSAGE
        else:
            continue

        lines.append({
            "custom_id": f"queue-{row['id']}",
            "method": "POST",
            "url": "/v1/chat/completions",
            "body": {
                "model": "gpt-4o",
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content},
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
    description="Réservé aux jobs COMPLETED. Applique chaque résultat à la bonne vision (analyse/résumé), revue (mg.analysis_review), ou plan (actions).",
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
            text("SELECT id, generation_type, target_id, request_payload FROM mg.ai_generation_queue WHERE id = :id"),
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
            elif queue_row["generation_type"] == "PLAN_ACTION_EXPLOSION":
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
            elif queue_row["generation_type"] == "PRIMARY_ANALYSIS":
                method = queue_row["request_payload"]["method"]
                model_cls = METHOD_MODELS[method]
                validated = model_cls(**parsed)
                db.execute(
                    text("""
                        INSERT INTO mg.pillar_analysis_drafts (vision_id, method, content, created_by)
                        VALUES (:vision_id, :method, CAST(:content AS jsonb), :created_by)
                    """),
                    {
                        "vision_id": queue_row["target_id"],
                        "method": method,
                        "content": validated.model_dump_json(),
                        "created_by": int(payload["sub"]),
                    },
                )
            elif queue_row["generation_type"] == "ANALYSIS_REVIEW":
                validated = ContentAnalysisReview(**parsed)
                issues_json = json.dumps([i.model_dump() for i in validated.issues], ensure_ascii=False)
                db.execute(
                    text("""
                        INSERT INTO mg.analysis_review (draft_id, review_status, issues)
                        VALUES (:draft_id, :status, CAST(:issues AS jsonb))
                    """),
                    {"draft_id": queue_row["target_id"], "status": validated.review_status, "issues": issues_json},
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
