"""Apply Postgres schema (destructive recreate) and list ccc tables."""
from __future__ import annotations

from src.postgres.db import apply_schema, connect


def main() -> int:
    with connect() as conn:
        apply_schema(conn)
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT table_schema || '.' || table_name
                FROM information_schema.tables
                WHERE table_schema = 'ccc'
                ORDER BY 1
                """
            )
            print("tables:", cur.fetchall())
    print("schema ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
