"""
SQLite Database Inspector CLI Tool (Person D)
Inspects tables, schema, and live records in phc_central.db and local_triage.db.
"""

import sqlite3
import os
import json


def inspect_database(db_file: str):
    print("=" * 60)
    print(f"[SQLITE DATABASE] Inspecting: {db_file}")
    print("=" * 60)

    if not os.path.exists(db_file):
        print(f"[!] Database file '{db_file}' does not exist yet.")
        print("    (Run 'python server.py' or 'python seed_data.py' to generate it.)\n")
        return

    conn = sqlite3.connect(db_file)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    # 1. Fetch Tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = [row["name"] for row in cursor.fetchall()]
    print(f"[+] Found {len(tables)} Tables: {', '.join(tables)}\n")

    for table in tables:
        print("-" * 50)
        cursor.execute(f"SELECT COUNT(*) as cnt FROM {table}")
        count = cursor.fetchone()["cnt"]
        print(f"[TABLE] '{table}' (Total Rows: {count})")

        # Table Columns
        cursor.execute(f"PRAGMA table_info({table});")
        cols = [f"{c['name']} ({c['type']})" for c in cursor.fetchall()]
        print(f"   Columns: {', '.join(cols)}")

        # Sample rows (up to 3)
        cursor.execute(f"SELECT * FROM {table} LIMIT 3;")
        rows = cursor.fetchall()
        if rows:
            print(f"   Sample Rows:")
            for i, r in enumerate(rows, 1):
                d = dict(r)
                summary = {k: v for k, v in d.items() if k in ['patient_id', 'full_name', 'triage_color', 'diagnosis', 'sync_status', 'urgency']}
                print(f"     Row {i}: {summary}")
        print()

    conn.close()


if __name__ == "__main__":
    print("\n--- ASHA / PHC Tele-Triage SQLite Database Inspector ---\n")
    inspect_database("phc_central.db")
    inspect_database("local_triage.db")

