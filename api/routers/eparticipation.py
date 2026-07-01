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


# ── Sprint 30 R2 -- File d'examen des contributions ───────────────────────────

DECISION_ROLES = {"ADMIN", "COMITE_TECH"}
GOVERNANCE_ROLES = {"ADMIN", "COMITE_TECH", "COMITE_SCI", "COMITE_ETHIQUE"}


class ReviewCreate(BaseModel):
    contribution_type: str
    contribution_id:   int
    step_number:       int
    verdict_code:      str
    comment:           Optional[str] = None


class DecisionCreate(BaseModel):
    contribution_type: str
    contribution_id:   int
    final_decision:    str
    justification:     Optional[str] = None


@router.post("/reviews",
    summary="Evaluer une contribution -- R2",
    description="Evaluation pilotee par les referentiels mg.review_steps et mg.review_verdicts.")
def submit_review(
    data: ReviewCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")

    # Charger l'etape depuis le referentiel
    step = db.execute(text("""
        SELECT step_number, criterion, evaluator_role
        FROM mg.review_steps
        WHERE step_number = :step AND is_active = TRUE
    """), {"step": data.step_number}).mappings().first()

    if not step:
        raise HTTPException(status_code=400, detail={
            "fr": f"Etape {data.step_number} invalide ou inactive.",
            "en": f"Step {data.step_number} is invalid or inactive."
        })

    # Verifier le role evaluateur
    if role != step["evaluator_role"] and role != "ADMIN":
        raise HTTPException(status_code=403, detail={
            "fr": f"L'etape {data.step_number} ({step['criterion']}) est reservee au role {step['evaluator_role']}.",
            "en": f"Step {data.step_number} ({step['criterion']}) is reserved for the {step['evaluator_role']} role."
        })

    # Verifier le verdict depuis le referentiel
    verdict = db.execute(text("""
        SELECT code, label_fr, label_en
        FROM mg.review_verdicts
        WHERE code = :code AND criterion = :criterion
    """), {"code": data.verdict_code, "criterion": step["criterion"]}).mappings().first()

    if not verdict:
        valid_verdicts = db.execute(text("""
            SELECT code FROM mg.review_verdicts WHERE criterion = :criterion
        """), {"criterion": step["criterion"]}).mappings().all()
        raise HTTPException(status_code=400, detail={
            "fr": f"Verdict invalide pour {step['criterion']}. Verdicts possibles : {[v['code'] for v in valid_verdicts]}",
            "en": f"Invalid verdict for {step['criterion']}. Possible verdicts: {[v['code'] for v in valid_verdicts]}"
        })

    if data.contribution_type not in ("TICKET", "PROPOSAL"):
        raise HTTPException(status_code=400, detail="Type invalide : TICKET ou PROPOSAL.")

    # Recuperer la politique pour cette transition
    policy = db.execute(text("""
        SELECT action FROM mg.review_policies
        WHERE criterion = :criterion AND verdict_code = :verdict
    """), {"criterion": step["criterion"], "verdict": data.verdict_code}).mappings().first()

    try:
        row = db.execute(text("""
            INSERT INTO mg.contribution_reviews
                (contribution_type, contribution_id, step_number,
                 criterion_code, verdict_code, affiliate_id, comment)
            VALUES
                (:type, :contrib_id, :step_number,
                 :criterion_code, :verdict_code, :affiliate_id, :comment)
            RETURNING id, evaluated_at
        """), {
            "type":           data.contribution_type,
            "contrib_id":     data.contribution_id,
            "step_number":    data.step_number,
            "criterion_code": step["criterion"],
            "verdict_code":   data.verdict_code,
            "affiliate_id":   int(payload["sub"]),
            "comment":        data.comment,
        }).mappings().one()

        # Recuperer l'etat actuel de la contribution
        tbl = 'pilot_tickets' if data.contribution_type == 'TICKET' else 'methodological_proposals'
        pk  = 'ticket_id'     if data.contribution_type == 'TICKET' else 'id'
        current_state_row = db.execute(text(
            f"SELECT workflow_state FROM mg.{tbl} WHERE {pk} = :id"
        ), {"id": data.contribution_id}).mappings().first()
        current_state = current_state_row["workflow_state"] if current_state_row else "SUBMITTED"

        # Calculer le prochain etat via mg.workflow_transitions
        action = policy["action"] if policy else "NEXT"
        next_state_row = db.execute(text("""
            SELECT to_state FROM mg.workflow_transitions
            WHERE from_state = :from_state AND trigger_action = :action
            LIMIT 1
        """), {"from_state": current_state, "action": action}).mappings().first()
        next_state = next_state_row["to_state"] if next_state_row else current_state

        # Mettre a jour le workflow_state sur la contribution
        db.execute(text(
            f"UPDATE mg.{tbl} SET workflow_state = :state WHERE {pk} = :id"
        ), {"state": next_state, "id": data.contribution_id})

        # Enregistrer dans workflow_history
        db.execute(text("""
            INSERT INTO mg.workflow_history
                (contribution_type, contribution_id, from_state, to_state,
                 trigger_action, affiliate_id, comment)
            VALUES
                (:type, :contrib_id, :from_state, :to_state,
                 :action, :affiliate_id, :comment)
        """), {
            "type":         data.contribution_type,
            "contrib_id":   data.contribution_id,
            "from_state":   current_state,
            "to_state":     next_state,
            "action":       action,
            "affiliate_id": int(payload["sub"]),
            "comment":      data.comment,
        })

        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": "Cette etape a deja ete evaluee pour cette contribution.",
            "en": "This step has already been evaluated for this contribution."
        })

    return {
        "id":            row["id"],
        "step_number":   data.step_number,
        "criterion":     step["criterion"],
        "verdict_code":  data.verdict_code,
        "policy_action": policy["action"] if policy else None,
        "evaluated_at":  str(row["evaluated_at"]),
        "message": {
            "fr": f"Etape {data.step_number} ({step['criterion']}) evaluee : {data.verdict_code}. Action : {policy['action'] if policy else 'N/A'}.",
            "en": f"Step {data.step_number} ({step['criterion']}) evaluated: {data.verdict_code}. Action: {policy['action'] if policy else 'N/A'}."
        }
    }


@router.get("/reviews/{contribution_type}/{contribution_id}",
    summary="Lister les evaluations d'une contribution -- R2",
    description="Reserve aux roles de gouvernance. Retourne les evaluations + workflow_history + decision finale.")
def get_reviews(
    contribution_type: str,
    contribution_id:   int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in GOVERNANCE_ROLES:
        raise HTTPException(status_code=403, detail={
            "fr": "Reserve aux roles de gouvernance OSA.",
            "en": "Reserved for OSA governance roles."
        })

    rows = db.execute(text("""
        SELECT r.id, r.step_number, r.criterion_code, r.verdict_code,
               r.comment, r.evaluated_at,
               s.label_fr AS step_label_fr, s.label_en AS step_label_en,
               s.evaluator_role,
               v.label_fr AS verdict_label_fr, v.label_en AS verdict_label_en,
               v.is_positive,
               p.action AS policy_action,
               a.first_name, a.last_name
        FROM mg.contribution_reviews r
        JOIN mg.review_steps   s ON s.criterion    = r.criterion_code
        JOIN mg.review_verdicts v ON v.code         = r.verdict_code
        LEFT JOIN mg.review_policies p ON p.criterion = r.criterion_code AND p.verdict_code = r.verdict_code
        LEFT JOIN mg.affiliates a ON a.id = r.affiliate_id
        WHERE r.contribution_type = :type AND r.contribution_id = :id
        ORDER BY r.step_number
    """), {"type": contribution_type.upper(), "id": contribution_id}).mappings().all()

    history = db.execute(text("""
        SELECT from_state, to_state, trigger_action, transitioned_at,
               a.first_name, a.last_name
        FROM mg.workflow_history h
        LEFT JOIN mg.affiliates a ON a.id = h.affiliate_id
        WHERE h.contribution_type = :type AND h.contribution_id = :id
        ORDER BY h.transitioned_at
    """), {"type": contribution_type.upper(), "id": contribution_id}).mappings().all()

    decision = db.execute(text("""
        SELECT final_decision, justification, decided_at
        FROM mg.contribution_decisions
        WHERE contribution_type = :type AND contribution_id = :id
    """), {"type": contribution_type.upper(), "id": contribution_id}).mappings().first()

    return {
        "contribution_type": contribution_type.upper(),
        "contribution_id":   contribution_id,
        "steps_completed":   len(rows),
        "steps_pending":     [s for s in range(1, 5) if s not in [r["step_number"] for r in rows]],
        "reviews": [{
            "step_number":     r["step_number"],
            "criterion":       r["criterion_code"],
            "step_label":      {"fr": r["step_label_fr"], "en": r["step_label_en"]},
            "evaluator_role":  r["evaluator_role"],
            "verdict":         r["verdict_code"],
            "verdict_label":   {"fr": r["verdict_label_fr"], "en": r["verdict_label_en"]},
            "is_positive":     r["is_positive"],
            "policy_action":   r["policy_action"],
            "comment":         r["comment"],
            "evaluated_at":    str(r["evaluated_at"]),
            "evaluator":       f"{r['first_name']} {r['last_name']}" if r["first_name"] else None,
        } for r in rows],
        "workflow_history": [{
            "from_state":     r["from_state"],
            "to_state":       r["to_state"],
            "trigger_action": r["trigger_action"],
            "transitioned_at": str(r["transitioned_at"]),
            "by":             f"{r['first_name']} {r['last_name']}" if r["first_name"] else None,
        } for r in history],
        "final_decision": {
            "decision":      decision["final_decision"],
            "justification": decision["justification"],
            "decided_at":    str(decision["decided_at"]),
        } if decision else None,
    }


@router.post("/decisions",
    summary="Rendre la decision finale -- R2",
    description="Reserve a ADMIN et COMITE_TECH. Synthetise les evaluations en une decision unique.")
def submit_decision(
    data: DecisionCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in DECISION_ROLES:
        raise HTTPException(status_code=403, detail={
            "fr": "La decision finale est reservee a l'equipe OSA et au Comite technique.",
            "en": "The final decision is reserved for the OSA team and the Technical Committee."
        })

    valid_decisions = db.execute(text("""
        SELECT final_decision FROM mg.contribution_decisions LIMIT 0
        UNION VALUES ('APPROVED'), ('REVISION_REQUESTED'), ('REJECTED'), ('ARCHIVED')
    """)).mappings().all()

    if data.final_decision not in ("APPROVED", "REVISION_REQUESTED", "REJECTED", "ARCHIVED"):
        raise HTTPException(status_code=400, detail={
            "fr": "Decision invalide. Choix : APPROVED, REVISION_REQUESTED, REJECTED, ARCHIVED.",
            "en": "Invalid decision. Choices: APPROVED, REVISION_REQUESTED, REJECTED, ARCHIVED."
        })

    try:
        row = db.execute(text("""
            INSERT INTO mg.contribution_decisions
                (contribution_type, contribution_id, final_decision,
                 justification, decided_by)
            VALUES (:type, :contrib_id, :decision, :justification, :decided_by)
            RETURNING id, decided_at
        """), {
            "type":          data.contribution_type,
            "contrib_id":    data.contribution_id,
            "decision":      data.final_decision,
            "justification": data.justification,
            "decided_by":    int(payload["sub"]),
        }).mappings().one()
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": "Une decision a deja ete rendue pour cette contribution.",
            "en": "A decision has already been made for this contribution."
        })

    return {
        "id":             row["id"],
        "final_decision": data.final_decision,
        "decided_at":     str(row["decided_at"]),
        "message": {
            "fr": f"Decision finale rendue : {data.final_decision}.",
            "en": f"Final decision rendered: {data.final_decision}."
        }
    }


# ── Sprint 30 R3 -- Cooptation vers les comites ───────────────────────────────

PROPOSE_ROLES  = {"COMITE_TECH"}
VALIDATE_ROLES = {"ADMIN"}


class CooptationCreate(BaseModel):
    affiliate_id:     int
    target_committee: str
    justification:    dict  # JSONB : scientific_reason, technical_reason, remarks...
    effective_from:   Optional[str] = None


class CooptationReview(BaseModel):
    status:          str
    review_comment:  Optional[str] = None
    effective_from:  Optional[str] = None
    deferred_until:  Optional[str] = None
    deferred_reason: Optional[str] = None


@router.post("/cooptations",
    summary="Proposer une cooptation -- R3",
    description="Reserve au Comite technique. Un affilie ne peut jamais se porter candidat.")
def propose_cooptation(
    data: CooptationCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in PROPOSE_ROLES and role != "ADMIN":
        raise HTTPException(status_code=403, detail={
            "fr": "La proposition de cooptation est reservee au Comite technique. Un affilie ne peut jamais se porter candidat a un comite -- la cooptation resulte de l'observation des contributions par le Comite technique.",
            "en": "Cooptation proposals are reserved for the Technical Committee. An affiliate can never apply to a committee -- cooptation results from the Technical Committee's observation of contributions."
        })

    # Verifier que le comite cible existe
    committee = db.execute(text("""
        SELECT code, label_fr, label_en FROM mg.committees
        WHERE code = :code AND is_active = TRUE
    """), {"code": data.target_committee}).mappings().first()

    if not committee:
        raise HTTPException(status_code=400, detail={
            "fr": f"Comite inconnu ou inactif : {data.target_committee}.",
            "en": f"Unknown or inactive committee: {data.target_committee}."
        })

    # Verifier que l'affilie n'est pas deja membre actif de ce comite
    existing_member = db.execute(text("""
        SELECT id FROM mg.committee_memberships
        WHERE affiliate_id = :affiliate_id AND committee = :committee AND status = 'ACTIVE'
    """), {"affiliate_id": data.affiliate_id, "committee": data.target_committee}).mappings().first()

    if existing_member:
        raise HTTPException(status_code=409, detail={
            "fr": "Cet affilie est deja membre actif de ce comite.",
            "en": "This affiliate is already an active member of this committee."
        })

    # Verifier qu'il n'y a pas deja une proposition en cours
    existing_proposal = db.execute(text("""
        SELECT id, status FROM mg.cooptation_proposals
        WHERE affiliate_id = :affiliate_id AND target_committee = :committee
        AND status IN ('PROPOSED', 'UNDER_REVIEW', 'DEFERRED')
    """), {"affiliate_id": data.affiliate_id, "committee": data.target_committee}).mappings().first()

    if existing_proposal:
        raise HTTPException(status_code=409, detail={
            "fr": f"Une proposition est deja en cours pour cet affilie ({existing_proposal['status']}).",
            "en": f"A proposal is already pending for this affiliate ({existing_proposal['status']})."
        })

    import json
    row = db.execute(text("""
        INSERT INTO mg.cooptation_proposals
            (affiliate_id, proposed_by, target_committee, justification,
             status, effective_from)
        VALUES
            (:affiliate_id, :proposed_by, :target_committee, :justification,
             'PROPOSED', :effective_from)
        RETURNING id, created_at
    """), {
        "affiliate_id":     data.affiliate_id,
        "proposed_by":      int(payload["sub"]),
        "target_committee": data.target_committee,
        "justification":    json.dumps(data.justification),
        "effective_from":   data.effective_from,
    }).mappings().one()
    db.commit()

    return {
        "id":         row["id"],
        "status":     "PROPOSED",
        "created_at": str(row["created_at"]),
        "message": {
            "fr": f"Proposition de cooptation soumise pour examen administratif. Comite cible : {committee['label_fr']}.",
            "en": f"Cooptation proposal submitted for administrative review. Target committee: {committee['label_en']}."
        }
    }


@router.get("/cooptations",
    summary="Lister les propositions de cooptation -- R3",
    description="Reserve a ADMIN et COMITE_TECH.")
def list_cooptations(
    status_filter: Optional[str] = None,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in {"ADMIN", "COMITE_TECH"}:
        raise HTTPException(status_code=403, detail={
            "fr": "Reserve a l'equipe OSA et au Comite technique.",
            "en": "Reserved for the OSA team and the Technical Committee."
        })

    conditions = []
    params = {}
    if status_filter:
        conditions.append("p.status = :status")
        params["status"] = status_filter.upper()
    where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""

    rows = db.execute(text(f"""
        SELECT p.id, p.status, p.justification, p.effective_from,
               p.deferred_until, p.deferred_reason, p.review_comment,
               p.created_at, p.reviewed_at,
               a.first_name AS aff_first, a.last_name AS aff_last, a.email AS aff_email,
               pb.first_name AS prop_first, pb.last_name AS prop_last,
               rb.first_name AS rev_first, rb.last_name AS rev_last,
               c.label_fr AS committee_fr, c.label_en AS committee_en
        FROM mg.cooptation_proposals p
        JOIN mg.affiliates a  ON a.id  = p.affiliate_id
        JOIN mg.affiliates pb ON pb.id = p.proposed_by
        JOIN mg.committees c  ON c.code = p.target_committee
        LEFT JOIN mg.affiliates rb ON rb.id = p.reviewed_by
        {where_clause}
        ORDER BY p.created_at DESC
    """), params).mappings().all()

    return [{
        "id":              r["id"],
        "status":          r["status"],
        "affiliate":       f"{r['aff_first']} {r['aff_last']} ({r['aff_email']})",
        "proposed_by":     f"{r['prop_first']} {r['prop_last']}",
        "committee":       {"fr": r["committee_fr"], "en": r["committee_en"]},
        "justification":   r["justification"],
        "effective_from":  str(r["effective_from"]) if r["effective_from"] else None,
        "deferred_until":  str(r["deferred_until"]) if r["deferred_until"] else None,
        "deferred_reason": r["deferred_reason"],
        "review_comment":  r["review_comment"],
        "reviewed_by":     f"{r['rev_first']} {r['rev_last']}" if r["rev_first"] else None,
        "created_at":      str(r["created_at"]),
        "reviewed_at":     str(r["reviewed_at"]) if r["reviewed_at"] else None,
    } for r in rows]


@router.patch("/cooptations/{proposal_id}",
    summary="Statuer sur une proposition de cooptation -- R3",
    description="Reserve a l'Admin. Decisions : APPROVED, DECLINED, CANCELLED, DEFERRED.")
def review_cooptation(
    proposal_id: int,
    data: CooptationReview,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role not in VALIDATE_ROLES:
        raise HTTPException(status_code=403, detail={
            "fr": "La validation d'une cooptation est reservee a l'administrateur OSA.",
            "en": "Cooptation validation is reserved for the OSA administrator."
        })

    valid_statuses = {"UNDER_REVIEW", "APPROVED", "DECLINED", "CANCELLED", "DEFERRED"}
    if data.status not in valid_statuses:
        raise HTTPException(status_code=400, detail={
            "fr": f"Statut invalide. Choix : {valid_statuses}",
            "en": f"Invalid status. Choices: {valid_statuses}"
        })

    if data.status == "DEFERRED" and not data.deferred_until:
        raise HTTPException(status_code=400, detail={
            "fr": "deferred_until est requis pour le statut DEFERRED.",
            "en": "deferred_until is required for DEFERRED status."
        })

    proposal = db.execute(text("""
        SELECT p.*, a.email, a.first_name, a.last_name,
               c.label_fr, c.label_en
        FROM mg.cooptation_proposals p
        JOIN mg.affiliates a ON a.id = p.affiliate_id
        JOIN mg.committees c ON c.code = p.target_committee
        WHERE p.id = :id
    """), {"id": proposal_id}).mappings().first()

    if not proposal:
        raise HTTPException(status_code=404, detail="Proposition non trouvee.")

    db.execute(text("""
        UPDATE mg.cooptation_proposals SET
            status         = :status,
            reviewed_by    = :reviewed_by,
            review_comment = :comment,
            effective_from = COALESCE(:effective_from, effective_from),
            deferred_until = :deferred_until,
            deferred_reason = :deferred_reason,
            reviewed_at    = NOW()
        WHERE id = :id
    """), {
        "status":          data.status,
        "reviewed_by":     int(payload["sub"]),
        "comment":         data.review_comment,
        "effective_from":  data.effective_from,
        "deferred_until":  data.deferred_until,
        "deferred_reason": data.deferred_reason,
        "id":              proposal_id,
    })

    # Si APPROVED -- creer le membership et mettre a jour le role
    if data.status == "APPROVED":
        db.execute(text("""
            INSERT INTO mg.committee_memberships
                (affiliate_id, committee, appointed_from, start_date, status)
            VALUES
                (:affiliate_id, :committee, :proposal_id, :start_date, 'ACTIVE')
        """), {
            "affiliate_id": proposal["affiliate_id"],
            "committee":    proposal["target_committee"],
            "proposal_id":  proposal_id,
            "start_date":   data.effective_from or str(__import__('datetime').date.today()),
        })

        # Attribuer le role dans mg.affiliate_roles
        db.execute(text("""
            INSERT INTO mg.affiliate_roles (affiliate_id, role_code, granted_by)
            VALUES (:affiliate_id, :role_code, :granted_by)
            ON CONFLICT (affiliate_id, role_code) DO NOTHING
        """), {
            "affiliate_id": proposal["affiliate_id"],
            "role_code":    proposal["target_committee"],
            "granted_by":   f"cooptation_proposal_{proposal_id}",
        })

    db.commit()

    return {
        "id":     proposal_id,
        "status": data.status,
        "message": {
            "fr": f"Proposition {proposal_id} : statut mis a jour ({data.status}).",
            "en": f"Proposal {proposal_id}: status updated ({data.status})."
        }
    }


# ── Sprint 30 R4.3 -- Dashboard securite + alertes Admin ──────────────────────

@router.get("/security/events",
    summary="Dashboard evenements de securite -- R4.3",
    description="Reserve a l'Admin. Liste les evenements non traites par severite.")
def get_security_events(
    severity:   Optional[str] = None,
    processed:  Optional[bool] = False,
    limit:      int = 50,
    payload:    dict = Depends(get_current_affiliate),
    db:         Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role != "ADMIN":
        raise HTTPException(status_code=403, detail={
            "fr": "Reserve a l'administrateur OSA.",
            "en": "Reserved for the OSA administrator."
        })

    conditions = []
    params = {"limit": limit}

    if severity:
        conditions.append("e.severity = :severity")
        params["severity"] = severity.upper()
    if processed is not None:
        conditions.append("e.processed = :processed")
        params["processed"] = processed

    where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""

    rows = db.execute(text(f"""
        SELECT e.id, e.event_type, e.severity, e.ip_address, e.email,
               e.domain, e.endpoint, e.details, e.processed,
               e.processed_at, e.created_at,
               t.label_fr, t.label_en, t.category,
               a.first_name, a.last_name
        FROM mg.security_events e
        JOIN mg.event_types t ON t.code = e.event_type
        LEFT JOIN mg.affiliates a ON a.id = e.affiliate_id
        {where_clause}
        ORDER BY e.created_at DESC
        LIMIT :limit
    """), params).mappings().all()

    # Compter les alertes non traitees par severite
    stats = db.execute(text("""
        SELECT severity, COUNT(*) AS count
        FROM mg.security_events
        WHERE processed = FALSE
        GROUP BY severity
        ORDER BY CASE severity
            WHEN 'CRITICAL' THEN 1
            WHEN 'ALERT'    THEN 2
            WHEN 'WARNING'  THEN 3
            ELSE 4 END
    """)).mappings().all()

    return {
        "unprocessed_summary": [{"severity": r["severity"], "count": r["count"]} for r in stats],
        "events": [{
            "id":           r["id"],
            "event_type":   r["event_type"],
            "category":     r["category"],
            "label":        {"fr": r["label_fr"], "en": r["label_en"]},
            "severity":     r["severity"],
            "ip_address":   r["ip_address"],
            "email":        r["email"],
            "domain":       r["domain"],
            "endpoint":     r["endpoint"],
            "details":      r["details"],
            "processed":    r["processed"],
            "processed_at": str(r["processed_at"]) if r["processed_at"] else None,
            "created_at":   str(r["created_at"]),
            "affiliate":    f"{r['first_name']} {r['last_name']}" if r["first_name"] else None,
        } for r in rows]
    }


@router.patch("/security/events/{event_id}/process",
    summary="Marquer un evenement comme traite -- R4.3",
    description="Reserve a l'Admin.")
def process_security_event(
    event_id: int,
    payload:  dict = Depends(get_current_affiliate),
    db:       Session = Depends(get_db),
):
    role = payload.get("role", "")
    if role != "ADMIN":
        raise HTTPException(status_code=403, detail={
            "fr": "Reserve a l'administrateur OSA.",
            "en": "Reserved for the OSA administrator."
        })

    result = db.execute(text("""
        UPDATE mg.security_events
        SET processed = TRUE, processed_at = NOW(), processed_by = :by
        WHERE id = :id AND processed = FALSE
        RETURNING id
    """), {"id": event_id, "by": int(payload["sub"])}).mappings().first()

    if not result:
        raise HTTPException(status_code=404, detail="Evenement non trouve ou deja traite.")

    db.commit()
    return {"id": event_id, "processed": True, "message": {
        "fr": "Evenement marque comme traite.",
        "en": "Event marked as processed."
    }}
