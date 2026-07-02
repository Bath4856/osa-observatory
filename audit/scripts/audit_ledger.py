#!/usr/bin/env python3

import json
import hashlib
import psycopg2


def compute_hash(payload):
    content = json.dumps(
        payload,
        sort_keys=True,
        default=str
    )

    return hashlib.sha256(
        content.encode("utf-8")
    ).hexdigest()


def get_connection():
    return psycopg2.connect(
        host="osa-db",
        port=5432,
        dbname="osa_db",
        user="postgres",
        password="postgres"
    )


def test_connection():
    conn = get_connection()

    cur = conn.cursor()

    cur.execute(
        "SELECT COUNT(*) FROM ops.audit_runs"
    )

    nb = cur.fetchone()[0]

    conn.close()

    return nb


if __name__ == "__main__":
    print(
        "OPS audit_runs rows:",
        test_connection()
    )
