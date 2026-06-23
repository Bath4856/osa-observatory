#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OSA ISA – Sprint 24 GAF v3
gaf_ledger.py

Nouveautés v3 :
- [A bis] finding_hash : SHA-256(module:finding_code:object_code)
  Détection de récurrence : si le hash existe déjà en DB,
  on incrémente recurrence_count au lieu d'insérer une nouvelle ligne.
- [B bis] publication_impact et iprs_weight lus depuis
  ops.gaf_iprs_calibration avant insertion.
- [E] get_kpis() enrichi avec MTTC, age_max, iprs_deduction_active.
"""

import hashlib
import json
import logging
import psycopg2

logger = logging.getLogger(__name__)


def compute_finding_hash(module: str, finding_code: str, object_code: str = None) -> str:
    """SHA-256(module:finding_code:object_code). Identifie un type de finding."""
    raw = f"{module}:{finding_code}:{object_code or ''}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


class GAFLedger:

    def __init__(self, cfg: dict):
        self.cfg = cfg

    def get_connection(self):
        return psycopg2.connect(
            host=self.cfg["db_host"], port=self.cfg["db_port"],
            dbname=self.cfg["db_name"], user=self.cfg["db_user"],
            password=self.cfg["db_password"],
        )

    def _load_calibration(self, cur) -> dict:
        """
        Charge la table ops.gaf_iprs_calibration en mémoire.
        Retourne {finding_code: {iprs_weight, publication_impact}}.
        """
        try:
            cur.execute("""
                SELECT finding_code, iprs_weight, publication_impact
                FROM ops.gaf_iprs_calibration
            """)
            return {
                row[0]: {"iprs_weight": float(row[1]), "publication_impact": row[2]}
                for row in cur.fetchall()
            }
        except Exception as e:
            logger.warning("Calibration non chargée : %s", e)
            return {}

    def save_findings(self, audit_id: int, oriented_result: dict) -> dict:
        """
        Persiste les findings orientés dans ops.*.

        Logique de récurrence :
          - Calcule finding_hash pour chaque finding
          - Si le hash existe déjà → UPDATE recurrence_count + detected_at
          - Sinon → INSERT avec first_seen_at = NOW()

        Calibration :
          - Charge ops.gaf_iprs_calibration
          - Injecte iprs_weight et publication_impact avant insertion
        """
        findings              = oriented_result.get("findings", [])
        findings_saved        = 0
        recurrences_updated   = 0
        recommendations_saved = 0

        conn = self.get_connection()
        conn.autocommit = False

        try:
            cur = conn.cursor()
            calibration = self._load_calibration(cur)

            for f in findings:
                finding_code = f.get("finding_code", "UNCLASSIFIED")
                object_code  = f.get("object_code")
                module       = f.get("module", "UNKNOWN")
                fhash        = compute_finding_hash(module, finding_code, object_code)

                # Calibration
                cal = calibration.get(finding_code, {})
                iprs_weight        = cal.get("iprs_weight",       f.get("iprs_weight", 0.0))
                publication_impact = cal.get("publication_impact", "NONE")

                # Vérifier récurrence : finding_hash déjà en DB et OPEN ?
                cur.execute("""
                    SELECT finding_id, recurrence_count
                    FROM ops.audit_findings
                    WHERE finding_hash = %s
                      AND status NOT IN ('CLOSED','RESOLVED')
                    ORDER BY detected_at DESC
                    LIMIT 1
                """, (fhash,))
                existing = cur.fetchone()

                if existing:
                    # Récurrence : incrémenter
                    existing_id        = existing[0]
                    recurrence_count   = existing[1] + 1
                    cur.execute("""
                        UPDATE ops.audit_findings
                        SET recurrence_count = %s,
                            detected_at      = NOW(),
                            audit_id         = %s,
                            raw_finding      = %s::jsonb
                        WHERE finding_id = %s
                    """, (recurrence_count, audit_id,
                          json.dumps(f.get("raw_finding", {})), existing_id))
                    recurrences_updated += 1
                    finding_id = existing_id

                else:
                    # Nouveau finding
                    cur.execute("""
                        INSERT INTO ops.audit_findings (
                            audit_id, module, finding_code, finding_hash,
                            severity, publication_impact, iprs_weight,
                            object_type, object_code, description,
                            raw_finding, status
                        )
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s::jsonb,'OPEN')
                        RETURNING finding_id
                    """, (
                        audit_id, module, finding_code, fhash,
                        f.get("severity", "INFO"), publication_impact, iprs_weight,
                        f.get("object_type"), object_code,
                        f.get("description", "")[:1000],
                        json.dumps(f.get("raw_finding", {})),
                    ))
                    finding_id = cur.fetchone()[0]
                    findings_saved += 1

                # Recommandation (toujours insérée pour traçabilité run)
                if f.get("recommended_action"):
                    cur.execute("""
                        INSERT INTO ops.audit_recommendations (
                            finding_id, recommended_action, priority,
                            owner, sprint_target, rule_code
                        )
                        VALUES (%s,%s,%s,%s,%s,%s)
                    """, (
                        finding_id,
                        f.get("recommended_action"),
                        f.get("priority", "MEDIUM"),
                        f.get("owner"),
                        f.get("sprint_target"),
                        f.get("rule_code"),
                    ))
                    recommendations_saved += 1

            conn.commit()
            logger.info(
                "GAF : %d nouveaux findings | %d récurrences | %d recommandations (audit_id=%s)",
                findings_saved, recurrences_updated, recommendations_saved, audit_id
            )
            return {
                "findings_saved":        findings_saved,
                "recurrences_updated":   recurrences_updated,
                "recommendations_saved": recommendations_saved,
            }

        except Exception:
            conn.rollback()
            logger.exception("GAF : erreur persistance findings")
            raise

        finally:
            conn.close()

    def get_open_findings(self, module: str = None) -> list[dict]:
        conn = self.get_connection()
        try:
            cur = conn.cursor()
            sql    = "SELECT * FROM ops.v_findings_open"
            params = []
            if module:
                sql += " WHERE module = %s"
                params.append(module)
            cur.execute(sql, params)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]
        finally:
            conn.close()

    def get_kpis(self) -> dict:
        """
        KPIs GAF enrichis v3 :
          - audit_resolution_rate_pct
          - open_by_severity + open_by_impact
          - iprs_deduction_active (total poids IPRS des findings ouverts)
          - mttc_days (Mean Time To Correction)
          - recommendation_closure_rate_pct
          - max_age_days (finding ouvert le plus ancien)
          - top_recurrent (finding le plus récurrent)
        """
        conn = self.get_connection()
        try:
            cur = conn.cursor()

            # KPIs principaux depuis v_gaf_iprs_impact
            cur.execute("SELECT * FROM ops.v_gaf_iprs_impact")
            cols = [d[0] for d in cur.description]
            row  = cur.fetchone()
            impact_kpis = dict(zip(cols, row)) if row else {}

            # Décomptes
            cur.execute("""
                SELECT
                    COUNT(*)                                        AS total,
                    COUNT(*) FILTER (WHERE status='CLOSED')        AS closed,
                    COUNT(*) FILTER (WHERE status='OPEN')          AS open,
                    COUNT(*) FILTER (WHERE severity='CRITICAL'
                        AND status!='CLOSED')                      AS critical_open,
                    COUNT(*) FILTER (WHERE severity='HIGH'
                        AND status!='CLOSED')                      AS high_open,
                    COUNT(*) FILTER (WHERE severity='MEDIUM'
                        AND status!='CLOSED')                      AS medium_open,
                    COUNT(*) FILTER (WHERE severity='LOW'
                        AND status!='CLOSED')                      AS low_open,
                    ROUND(100.0*COUNT(*) FILTER(WHERE status='CLOSED')
                        /GREATEST(COUNT(*),1),2)                   AS resolution_rate,
                    MAX(recurrence_count)                           AS max_recurrence,
                    MAX(EXTRACT(DAY FROM NOW()-first_seen_at))
                        FILTER (WHERE status!='CLOSED')            AS max_age_days
                FROM ops.audit_findings
            """)
            row2 = cur.fetchone()

            # Finding le plus récurrent
            cur.execute("""
                SELECT finding_code, module, recurrence_count
                FROM ops.audit_findings
                WHERE status != 'CLOSED'
                ORDER BY recurrence_count DESC LIMIT 1
            """)
            top_rec = cur.fetchone()

            return {
                "total":               row2[0],
                "total_closed":        row2[1],
                "total_open":          row2[2],
                "open_by_severity": {
                    "CRITICAL": row2[3], "HIGH": row2[4],
                    "MEDIUM":   row2[5], "LOW":  row2[6],
                },
                "audit_resolution_rate_pct":     float(row2[7] or 0),
                "max_recurrence":                row2[8],
                "max_age_days":                  int(row2[9] or 0),
                "iprs_deduction_active":         float(impact_kpis.get("iprs_deduction_active") or 0),
                "iprs_deduction_blocking":       float(impact_kpis.get("iprs_deduction_blocking") or 0),
                "blocking_findings_open":        impact_kpis.get("blocking_findings_open", 0),
                "conditional_findings_open":     impact_kpis.get("conditional_findings_open", 0),
                "mttc_days":                     float(impact_kpis.get("mttc_days") or 0),
                "recommendation_closure_rate_pct": float(impact_kpis.get("recommendation_closure_rate_pct") or 0),
                "top_recurrent": {
                    "finding_code":     top_rec[0],
                    "module":           top_rec[1],
                    "recurrence_count": top_rec[2],
                } if top_rec else None,
            }

        finally:
            conn.close()
