#!/usr/bin/env python3
"""
governance_synchronizer.py -- Synchroniseur générique du bus de
gouvernance événementielle (ADR-004). Remplace, pour tout domaine
présent ou futur, identity_synchronizer.py -- lequel reste en place,
inchangé, mais devient dormant par construction (plus aucune écriture
nouvelle dans mg.identity_events depuis la bascule du domaine IDENTITY
vers mg.governance_events, ADR-003 Phase 3).

Lit les événements PENDING et FAILED ciblant PROD dans
mg.governance_events sur osa_preprod, tous domaines confondus, en les
réservant UN PAR UN via UPDATE ... FOR UPDATE SKIP LOCKED (idiome
standard de file d'attente concurrente PostgreSQL) avant application --
répond à l'exigence 4 du finding GAF #39 GOVERNANCE_BUS_IDEMPOTENCE_
REQUIREMENTS : deux exécutions concurrentes de ce script ne peuvent pas
réserver le même événement, chacune passe naturellement au suivant
disponible (SKIP LOCKED).

Réservation événement par événement plutôt qu'en lot : si le script
est interrompu en cours d'exécution, un seul événement au maximum reste
bloqué en statut IN_PROGRESS -- jamais un lot entier. Ce risque résiduel
(un événement IN_PROGRESS orphelin après un crash) reste une limite
connue, à traiter avec la distinction transitoire/permanent déjà
documentée comme dette technique (ADR-003, finding #38) dans la fiche
GAF finale d'idempotence prévue avant la Phase 6.

Correctif du 14 juillet 2026 -- bouclage infini corrigé : un événement
qui échoue et repasse en FAILED n'est plus jamais repris au sein de la
MEME exécution du script (exclusion explicite via processed_uuids).
Sans ce correctif, un échec systématique (ex. endpoint cible absent)
provoquait une boucle sans fin sur le même événement, jusqu'à
interruption manuelle. Un événement FAILED n'est retenté qu'au
prochain lancement du script (cron suivant, ou rappel manuel).

Correctif du 14 juillet 2026 (2) -- tri par seq (BIGSERIAL) au lieu de
created_at pour la réservation d'événement. Bug découvert en test réel :
deux événements émis dans la même transaction (ex. AFFILIATE_CONFIRMED
puis WORKING_GROUP_ACTIVATED lors d'une confirmation d'email) partagent
un created_at strictement identique -- NOW() est figé pour toute la
durée d'une transaction PostgreSQL. Sans tiebreaker fiable, l'ordre de
traitement entre deux événements à égalité n'était pas garanti,
provoquant un 409 quand une dépendance métier (l'affilié doit exister
avant son rattachement à un groupe de travail) était traitée dans le
mauvais ordre. La colonne seq, adossée à une séquence dédiée, garantit
l'ordre réel d'insertion indépendamment de NOW().

Correctif du 14 juillet 2026 (3) -- reprise des verrous IN_PROGRESS
orphelins. Bug confirmé en test réel (exigence 4, finding GAF #39) :
l'interruption brutale de deux instances concurrentes du synchroniseur
(piège de shell -- docker exec -i lancé en arrière-plan, SIGTTIN) a
laissé un événement bloqué en IN_PROGRESS, sans aucune reprise
automatique possible. Corrigé par l'ajout de claimed_at, horodaté à la
réservation : un IN_PROGRESS n'est repris que si son verrou date de
plus de STALE_LOCK_MINUTES (2 minutes) -- distingue un verrou orphelin
d'un traitement légitime en cours par une autre instance, sans annuler
la protection contre le traitement concurrent (FOR UPDATE SKIP LOCKED).

Usage :
  ~/flyer-venv/bin/python3 governance_synchronizer.py

Variables d'environnement :
  IDENTITY_SYNC_SECRET  (obligatoire -- même secret partagé que
                          l'ancien mécanisme, aucune rotation requise
                          par cette généralisation)
  PROD_API_BASE         (défaut: https://open.osa-observatory.africa/api)

Note héritée d'identity_synchronizer.py (12-13 juillet 2026) :
l'interpolation de variables psql (-v nom=valeur, syntaxe :'nom') ne
fonctionne pas dans cet environnement -- tout littéral SQL est
construit côté Python via _sql_literal(), jamais via cette
interpolation.
"""
import json
import os
import subprocess
import sys

import requests

PROD_API_BASE = os.getenv("PROD_API_BASE", "https://open.osa-observatory.africa/api")
SYNC_SECRET = os.getenv("IDENTITY_SYNC_SECRET")

# Delai au-dela duquel un evenement IN_PROGRESS est considere comme un
# verrou orphelin (crash du synchroniseur) plutot qu'un traitement
# legitime en cours -- tres superieur au timeout HTTP de 15s d'
# apply_event(), pour ne jamais reprendre un traitement reellement actif.
STALE_LOCK_MINUTES = 2


def psql(database: str, sql: str):
    """Execute une requete via docker exec psql. Le SQL fourni doit deja
    etre complet et sur -- aucune substitution de variable psql n'est
    utilisee (interpolation -v/:'var' non fonctionnelle dans cet
    environnement, confirme lors du debogage d'identity_synchronizer.py)."""
    cmd = ["docker", "exec", "-i", "osa-db", "psql", "-U", "postgres", "-d", database,
           "-t", "-A", "-q", "-c", sql]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"psql error ({database}): {result.stderr.strip()}")
    return result.stdout.strip()


def _sql_literal(value) -> str:
    """Echappement manuel d'un litteral SQL de type texte (doublement des
    apostrophes). N'accepte que des chaines simples."""
    return "'" + str(value).replace("'", "''") + "'"


def claim_one_event(exclude_uuids: set):
    """
    Réserve atomiquement UN SEUL événement ciblant PROD, tous domaines
    confondus -- passage à IN_PROGRESS via le motif standard PostgreSQL
    de file d'attente concurrente (CTE + FOR UPDATE SKIP LOCKED). Une
    exécution concurrente de ce script ignore les lignes déjà
    verrouillées par cette réservation et passe à la suivante
    disponible, sans attente ni double réservation.

    Éligibles à la réservation :
      - PENDING ou FAILED (cas normal)
      - IN_PROGRESS dont claimed_at date de plus de STALE_LOCK_MINUTES
        -- verrou orphelin après un crash du synchroniseur (confirmé en
        test réel le 14 juillet 2026 : une interruption brutale de deux
        instances concurrentes a laissé un événement bloqué en
        IN_PROGRESS sans aucune reprise possible). Un IN_PROGRESS plus
        récent que ce délai est considéré comme un traitement légitime
        en cours par une autre instance -- jamais repris, pour ne pas
        annuler la protection contre le traitement concurrent.

    exclude_uuids : événements déjà traités (avec succès ou échec) dans
    CETTE exécution -- un FAILED qui vient d'être marqué ne doit
    jamais être repris dans la même boucle (cf. correctif du 14 juillet
    2026 (1)). Un événement FAILED n'est retenté qu'au prochain
    lancement du script (cron suivant, ou rappel manuel).

    Retourne None si aucun événement n'est disponible.
    """
    exclude_sql = "ARRAY[]::uuid[]" if not exclude_uuids else (
        "ARRAY[" + ",".join(_sql_literal(u) for u in exclude_uuids) + "]::uuid[]"
    )
    raw = psql("osa_preprod", f"""
        WITH next_event AS (
            SELECT event_uuid FROM mg.governance_events
            WHERE target_environment = 'PROD'
              AND (
                    status IN ('PENDING', 'FAILED')
                    OR (status = 'IN_PROGRESS' AND claimed_at < NOW() - INTERVAL '{STALE_LOCK_MINUTES} minutes')
                  )
              AND event_uuid <> ALL({exclude_sql})
            ORDER BY seq
            FOR UPDATE SKIP LOCKED
            LIMIT 1
        ),
        updated AS (
            UPDATE mg.governance_events g
            SET status = 'IN_PROGRESS', claimed_at = NOW()
            FROM next_event
            WHERE g.event_uuid = next_event.event_uuid
            RETURNING g.event_uuid, g.domain_code, g.event_type,
                      g.object_uuid::text AS object_uuid, g.payload
        )
        SELECT COALESCE(json_agg(updated), '[]'::json) FROM updated;
    """)
    rows = json.loads(raw) if raw else []
    return rows[0] if rows else None


def mark_event(event_uuid: str, status: str, error_detail: str = ""):
    error_sql = "NULL" if not error_detail else _sql_literal(error_detail)
    sql = f"""
        UPDATE mg.governance_events
        SET status = {_sql_literal(status)}, propagated_at = NOW(),
            propagated_by = 'GOVERNANCE_SYNCHRONIZER', error_detail = {error_sql}
        WHERE event_uuid = {_sql_literal(event_uuid)};
    """
    psql("osa_preprod", sql)


def apply_event(event: dict) -> tuple[bool, str]:
    try:
        res = requests.post(
            f"{PROD_API_BASE}/v1/sync/apply-event",
            headers={"X-Sync-Secret": SYNC_SECRET, "Content-Type": "application/json"},
            json={
                "domain_code": event["domain_code"],
                "event_type": event["event_type"],
                "object_uuid": event["object_uuid"],
                "payload": event["payload"],
            },
            timeout=15,
        )
        if res.ok:
            return True, ""
        return False, f"HTTP {res.status_code} -- {res.text[:500]}"
    except requests.RequestException as e:
        return False, str(e)[:500]


def main():
    if not SYNC_SECRET:
        print("Erreur : IDENTITY_SYNC_SECRET non défini.", file=sys.stderr)
        sys.exit(1)

    ok_count = fail_count = 0
    processed_uuids = set()

    while True:
        event = claim_one_event(processed_uuids)
        if event is None:
            break
        processed_uuids.add(event["event_uuid"])

        # Toute exception inattendue pendant l'application est
        # capturée ici -- garantit que l'événement réservé ne reste
        # jamais bloqué en IN_PROGRESS sans marquage final, même en
        # cas d'erreur non prévue par apply_event().
        try:
            success, error = apply_event(event)
        except Exception as e:
            success, error = False, str(e)[:500]

        label = f"[{event['domain_code']}] {event['event_type']} ({event['object_uuid'][:8]}...)"
        if success:
            mark_event(event["event_uuid"], "PROPAGATED")
            print(f"  ✓ {label} propagé.")
            ok_count += 1
        else:
            mark_event(event["event_uuid"], "FAILED", error)
            print(f"  ✗ {label} échec : {error}", file=sys.stderr)
            fail_count += 1

    if ok_count == 0 and fail_count == 0:
        print("Aucun événement en attente.")
    else:
        print(f"\nTerminé -- {ok_count} propagé(s), {fail_count} échec(s).")


if __name__ == "__main__":
    main()
