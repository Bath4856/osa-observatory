"""
OSA Observatory -- Sprint 30 Lot D1
Router E-Participation -- Contributions tracables affilies authentifies
GET /api/v1/consultation/my-contributions
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate

router = APIRouter(
    prefix="/api/v1/consultation",
    tags=["E-participation"],
)

# Roles avec acces a l'historique complet (D1)
FULL_HISTORY_ROLES = {"ADMIN", "COMITE_TECH", "COMITE_SCI", "COMITE_ETHIQUE"}

class TicketHistoryItem(BaseModel):
    ticket_ref:   str
    ticket_type:  str
    status:       str
    subject:      Optional[str] = None
    submitter_name: Optional[str] = None
    country_iso3: Optional[str] = None
    pillar_code:  Optional[str] = None
    created_at:   str
    resolved_at:  Optional[str] = None


@router.get("/my-contributions",
    response_model=List[TicketHistoryItem],
    summary="Historique des contributions -- D1",
    description=(
        "Retourne l'historique des contributions. "
        "AFFILIE : ses propres contributions uniquement. "
        "ADMIN/COMITE_TECH/COMITE_SCI/COMITE_ETHIQUE : historique complet."
    ),
)
def get_my_contributions(
    limit: int = 50,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    role = payload.get("role", "AFFILIE")

    if role in FULL_HISTORY_ROLES:
        rows = db.execute(text("""
            SELECT ticket_ref, ticket_type, status, subject,
                   submitter_name, country_iso3, pillar_code,
                   created_at, resolved_at
            FROM mg.pilot_tickets
            ORDER BY created_at DESC
            LIMIT :limit
        """), {"limit": limit}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT ticket_ref, ticket_type, status, subject,
                   submitter_name, country_iso3, pillar_code,
                   created_at, resolved_at
            FROM mg.pilot_tickets
            WHERE affiliate_id = :affiliate_id
            ORDER BY created_at DESC
            LIMIT :limit
        """), {"affiliate_id": affiliate_id, "limit": limit}).mappings().all()

    return [
        {
            "ticket_ref":     r["ticket_ref"],
            "ticket_type":    r["ticket_type"],
            "status":         r["status"],
            "subject":        r["subject"],
            "submitter_name": r["submitter_name"],
            "country_iso3":   r["country_iso3"],
            "pillar_code":    r["pillar_code"],
            "created_at":     str(r["created_at"]),
            "resolved_at":    str(r["resolved_at"]) if r["resolved_at"] else None,
        }
        for r in rows
    ]


class ContributionCreate(BaseModel):
    ticket_type:    str
    subject:        str
    description:    str
    country_iso3:   Optional[str] = None
    pillar_code:    Optional[str] = None
    indicator_code: Optional[str] = None
    year_concerned: Optional[int] = None
    evidence_url:   Optional[str] = None


@router.post("/contributions",
    summary="Soumettre une contribution tracable -- D1",
    description="Soumission authentifiee liee a affiliate_id. Roles : tous affilies actifs.")
def submit_contribution(
    data: ContributionCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    email = payload.get("email", "")

    allowed_types = ("QUESTION", "SUGGESTION")
    if data.ticket_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Type {data.ticket_type} non autorise. Utiliser QUESTION ou SUGGESTION."
        )

    affiliate = db.execute(
        text("SELECT first_name, last_name FROM mg.affiliates WHERE id = :id"),
        {"id": affiliate_id}
    ).mappings().first()
    full_name = f"{affiliate['first_name']} {affiliate['last_name']}" if affiliate else email

    row = db.execute(text("""
        INSERT INTO mg.pilot_tickets
            (ticket_type, subject, description,
             submitter_email, submitter_name, affiliate_id,
             country_iso3, pillar_code, indicator_code, year_concerned,
             evidence_url)
        VALUES
            (:type, :subject, :description,
             :email, :name, :affiliate_id,
             :iso3, :pillar, :indicator, :year,
             :evidence)
        RETURNING ticket_id, ticket_ref, status, created_at
    """), {
        "type":        data.ticket_type,
        "subject":     data.subject,
        "description": data.description,
        "email":       email,
        "name":        full_name,
        "affiliate_id": affiliate_id,
        "iso3":        data.country_iso3.upper() if data.country_iso3 else None,
        "pillar":      data.pillar_code.upper() if data.pillar_code else None,
        "indicator":   data.indicator_code.upper() if data.indicator_code else None,
        "year":        data.year_concerned,
        "evidence":    data.evidence_url,
    }).mappings().one()
    db.commit()

    return {
        "ticket_ref": row["ticket_ref"],
        "ticket_id":  row["ticket_id"],
        "status":     row["status"],
        "created_at": str(row["created_at"]),
        "message":    {"fr": f"Contribution {row['ticket_ref']} enregistree et liee a votre profil affilie.", "en": f"Contribution {row['ticket_ref']} recorded and linked to your affiliate profile."},
    }


# ── Sprint 30 Lot D2 -- Commentaires structures ───────────────────────────────

COMMENT_ROLES = {"COMITE_TECH", "COMITE_SCI", "COMITE_ETHIQUE"}
MODERATE_ROLES = {"ADMIN", "COMITE_TECH", "COMITE_SCI"}

VALID_METHODS = {
    "5W1H":       {"who", "what", "when", "where", "why", "how"},
    "SWOT":       {"strengths", "weaknesses", "opportunities", "threats"},
    "5_POURQUOI": {"pourquoi_1", "pourquoi_2", "pourquoi_3", "pourquoi_4", "pourquoi_5", "conclusion"},
}


class CommentCreate(BaseModel):
    country_iso3:   Optional[str] = None
    pillar_code:    Optional[str] = None
    indicator_code: Optional[str] = None
    method:         str
    content:        dict


def require_comite_role(payload: dict):
    role = payload.get("role", "")
    if role not in COMMENT_ROLES and role != "ADMIN":
        raise HTTPException(
            status_code=403,
            detail={
                "fr": "Cette action est reservee aux comites de validation scientifique (Technique, Scientifique, Ethique). Les affilies participent a la production collective des connaissances ; les comites assurent l'expertise et la validation des analyses officielles.",
                "en": "This action is reserved for the scientific validation committees (Technical, Scientific, Ethics). Affiliates contribute to the collective production of knowledge; committees ensure the expertise and validation of official analyses."
            }
        )


@router.post("/comments",
    summary="Creer un commentaire structure -- D2",
    description="Reserve aux roles COMITE_TECH, COMITE_SCI, COMITE_ETHIQUE, ADMIN. Methode au choix : 5W1H, SWOT, 5_POURQUOI.")
def create_comment(
    data: CommentCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    require_comite_role(payload)

    if data.method not in VALID_METHODS:
        raise HTTPException(status_code=400, detail=f"Methode invalide. Choix : {list(VALID_METHODS.keys())}")

    if not (data.country_iso3 or data.pillar_code or data.indicator_code):
        raise HTTPException(status_code=400, detail="Au moins un champ de portee requis : country_iso3, pillar_code ou indicator_code.")

    expected_keys = VALID_METHODS[data.method]
    provided_keys = set(data.content.keys())
    if not expected_keys.issubset(provided_keys):
        missing = expected_keys - provided_keys
        raise HTTPException(status_code=400, detail=f"Champs manquants pour {data.method} : {missing}")

    import json
    row = db.execute(text("""
        INSERT INTO mg.indicator_comments
            (affiliate_id, country_iso3, pillar_code, indicator_code, method, content)
        VALUES
            (:affiliate_id, :iso3, :pillar, :indicator, :method, :content)
        RETURNING id, created_at
    """), {
        "affiliate_id": int(payload["sub"]),
        "iso3":         data.country_iso3.upper() if data.country_iso3 else None,
        "pillar":       data.pillar_code.upper() if data.pillar_code else None,
        "indicator":    data.indicator_code.upper() if data.indicator_code else None,
        "method":       data.method,
        "content":      json.dumps(data.content),
    }).mappings().one()
    db.commit()

    return {
        "id":         row["id"],
        "created_at": str(row["created_at"]),
        "message":    {"fr": "Commentaire enregistre.", "en": "Comment recorded."},
    }


@router.get("/comments",
    summary="Lister les commentaires -- D2",
    description="Reserve aux roles COMITE_TECH, COMITE_SCI, COMITE_ETHIQUE, ADMIN. Filtrable par pays/pilier/indicateur.")
def list_comments(
    country_iso3:   Optional[str] = None,
    pillar_code:    Optional[str] = None,
    indicator_code: Optional[str] = None,
    status:         Optional[str] = None,
    limit:          int = 50,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    require_comite_role(payload)

    conditions = []
    params = {"limit": limit}
    if country_iso3:
        conditions.append("country_iso3 = :iso3")
        params["iso3"] = country_iso3.upper()
    if pillar_code:
        conditions.append("pillar_code = :pillar")
        params["pillar"] = pillar_code.upper()
    if indicator_code:
        conditions.append("indicator_code = :indicator")
        params["indicator"] = indicator_code.upper()
    if status:
        conditions.append("c.status = :status")
        params["status"] = status.upper()

    where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""

    rows = db.execute(text(f"""
        SELECT c.id, c.country_iso3, c.pillar_code, c.indicator_code,
               c.method, c.content, c.status, c.created_at, c.updated_at,
               a.first_name, a.last_name, a.org_name
        FROM mg.indicator_comments c
        JOIN mg.affiliates a ON a.id = c.affiliate_id
        {where_clause}
        ORDER BY c.created_at DESC
        LIMIT :limit
    """), params).mappings().all()

    return [
        {
            "id":             r["id"],
            "country_iso3":   r["country_iso3"],
            "pillar_code":    r["pillar_code"],
            "indicator_code": r["indicator_code"],
            "method":         r["method"],
            "content":        r["content"],
            "status":         r["status"],
            "created_at":     str(r["created_at"]),
            "updated_at":     str(r["updated_at"]),
            "author":         f"{r['first_name']} {r['last_name']} ({r['org_name']})",
        }
        for r in rows
    ]


@router.patch("/comments/{comment_id}/status",
    summary="Moderer un commentaire -- D2",
    description="Reserve a ADMIN, COMITE_TECH, COMITE_SCI. Change le statut OPEN/RESOLVED/ARCHIVED.")
def moderate_comment(
    comment_id: int,
    new_status: str,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in MODERATE_ROLES:
        raise HTTPException(status_code=403, detail={
            "fr": "Cette action de moderation est reservee a l'equipe OSA et aux comites de gouvernance (Technique, Scientifique).",
            "en": "This moderation action is reserved for the OSA team and governance committees (Technical, Scientific)."
        })

    if new_status not in ("OPEN", "RESOLVED", "ARCHIVED"):
        raise HTTPException(status_code=400, detail="Statut invalide. Choix : OPEN, RESOLVED, ARCHIVED.")

    result = db.execute(text("""
        UPDATE mg.indicator_comments
        SET status = :status, updated_at = NOW()
        WHERE id = :id
        RETURNING id
    """), {"status": new_status, "id": comment_id}).mappings().first()

    if not result:
        raise HTTPException(status_code=404, detail="Commentaire non trouve.")

    db.commit()
    return {"id": comment_id, "status": new_status, "message": {"fr": "Statut mis a jour.", "en": "Status updated."}}


# ── Sprint 30 Lot D3 -- Votes methodologiques ─────────────────────────────────

INITIATE_ROLES = {"ADMIN", "COMITE_TECH"}
VOTE_ROLE = "COMITE_SCI"


class ProposalCreate(BaseModel):
    title:       str
    description: str
    deadline:    str  # ISO date string


class VoteCreate(BaseModel):
    score:   int
    comment: Optional[str] = None


@router.post("/proposals",
    summary="Initier une proposition methodologique -- D3",
    description="Reserve a ADMIN et COMITE_TECH. Definit une date limite de vote.")
def create_proposal(
    data: ProposalCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in INITIATE_ROLES:
        raise HTTPException(status_code=403, detail={
            "fr": "Cette action est reservee a l'equipe de l'OSA et aux membres du Comite technique. Les propositions methodologiques sont preparees par l'equipe de l'OSA ou le Comite technique, puis soumises a l'examen et au vote du Comite scientifique conformement au processus de gouvernance de l'Observatoire.",
            "en": "This action is reserved for the OSA team and members of the Technical Committee. Methodological proposals are prepared by the OSA team or the Technical Committee before being submitted to the Scientific Committee for review and vote, in accordance with the Observatory's governance process."
        })

    row = db.execute(text("""
        INSERT INTO mg.methodological_proposals
            (initiated_by, title, description, deadline)
        VALUES
            (:initiated_by, :title, :description, :deadline)
        RETURNING id, created_at
    """), {
        "initiated_by": int(payload["sub"]),
        "title":        data.title,
        "description":  data.description,
        "deadline":     data.deadline,
    }).mappings().one()
    db.commit()

    return {
        "id":         row["id"],
        "created_at": str(row["created_at"]),
        "message":    {"fr": "Proposition methodologique creee. Vote ouvert au Comite scientifique.", "en": "Methodological proposal created. Vote open to the Scientific Committee."},
    }


@router.get("/proposals",
    summary="Lister les propositions methodologiques -- D3",
    description="Accessible a tous les roles de gouvernance. Resultats masques tant que la proposition est OPEN.")
def list_proposals(
    status_filter: Optional[str] = None,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in (INITIATE_ROLES | {VOTE_ROLE}):
        raise HTTPException(status_code=403, detail={
            "fr": "Reserve aux roles de gouvernance OSA.",
            "en": "Reserved for OSA governance roles."
        })

    conditions = []
    params = {}
    if status_filter:
        conditions.append("p.status = :status")
        params["status"] = status_filter.upper()
    where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""

    rows = db.execute(text(f"""
        SELECT p.id, p.title, p.description, p.deadline, p.status,
               p.created_at, p.closed_at,
               a.first_name, a.last_name,
               COUNT(v.id) AS nb_votes
        FROM mg.methodological_proposals p
        JOIN mg.affiliates a ON a.id = p.initiated_by
        LEFT JOIN mg.proposal_votes v ON v.proposal_id = p.id
        {where_clause}
        GROUP BY p.id, a.first_name, a.last_name
        ORDER BY p.created_at DESC
    """), params).mappings().all()

    result = []
    for r in rows:
        item = {
            "id":           r["id"],
            "title":        r["title"],
            "description":  r["description"],
            "deadline":     str(r["deadline"]),
            "status":       r["status"],
            "created_at":   str(r["created_at"]),
            "closed_at":    str(r["closed_at"]) if r["closed_at"] else None,
            "initiated_by": f"{r['first_name']} {r['last_name']}",
            "nb_votes":     r["nb_votes"],
        }
        # Resultats visibles uniquement si CLOSED
        if r["status"] == "CLOSED":
            avg_row = db.execute(text("""
                SELECT AVG(score)::numeric(3,2) AS avg_score
                FROM mg.proposal_votes WHERE proposal_id = :id
            """), {"id": r["id"]}).mappings().first()
            item["average_score"] = float(avg_row["avg_score"]) if avg_row["avg_score"] else None
        result.append(item)

    return result


@router.post("/proposals/{proposal_id}/vote",
    summary="Voter sur une proposition methodologique -- D3",
    description="Reserve exclusivement au Comite scientifique. Note 1-5. Un seul vote par membre.")
def vote_proposal(
    proposal_id: int,
    data: VoteCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role != VOTE_ROLE:
        raise HTTPException(status_code=403, detail={
            "fr": "Le vote sur les propositions methodologiques est reserve exclusivement au Comite scientifique, garant de l'autorite scientifique des decisions methodologiques de l'OSA.",
            "en": "Voting on methodological proposals is reserved exclusively for the Scientific Committee, which safeguards the scientific authority of OSA's methodological decisions."
        })

    if not (1 <= data.score <= 5):
        raise HTTPException(status_code=400, detail="Score doit etre entre 1 et 5.")

    proposal = db.execute(text("""
        SELECT status, deadline FROM mg.methodological_proposals WHERE id = :id
    """), {"id": proposal_id}).mappings().first()

    if not proposal:
        raise HTTPException(status_code=404, detail="Proposition non trouvee.")
    if proposal["status"] == "CLOSED":
        raise HTTPException(status_code=400, detail="Cette proposition est cloturee -- vote impossible.")

    try:
        db.execute(text("""
            INSERT INTO mg.proposal_votes (proposal_id, affiliate_id, score, comment)
            VALUES (:proposal_id, :affiliate_id, :score, :comment)
        """), {
            "proposal_id":  proposal_id,
            "affiliate_id": int(payload["sub"]),
            "score":        data.score,
            "comment":      data.comment,
        })
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=409, detail="Vous avez deja vote sur cette proposition.")

    return {"message": {"fr": "Vote enregistre. Les resultats seront visibles a la cloture de la proposition.", "en": "Vote recorded. Results will be visible once the proposal is closed."}}


@router.patch("/proposals/{proposal_id}/close",
    summary="Cloturer une proposition -- D3",
    description="Reserve a ADMIN et COMITE_TECH. Rend les resultats visibles.")
def close_proposal(
    proposal_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in INITIATE_ROLES:
        raise HTTPException(status_code=403, detail={
            "fr": "Seuls l'equipe OSA et le Comite technique peuvent cloturer une proposition.",
            "en": "Only the OSA team and the Technical Committee can close a proposal."
        })

    result = db.execute(text("""
        UPDATE mg.methodological_proposals
        SET status = 'CLOSED', closed_at = NOW()
        WHERE id = :id AND status = 'OPEN'
        RETURNING id
    """), {"id": proposal_id}).mappings().first()

    if not result:
        raise HTTPException(status_code=404, detail="Proposition non trouvee ou deja cloturee.")

    db.commit()
    return {"id": proposal_id, "status": "CLOSED", "message": {"fr": "Proposition cloturee. Resultats desormais visibles.", "en": "Proposal closed. Results now visible."}}
