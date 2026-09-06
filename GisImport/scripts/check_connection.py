"""Quick DB connectivity check (no secrets printed)."""
from __future__ import annotations

import sys

from src.config import load_database_url
from src.db import connect


def main() -> int:
    url = load_database_url()
    host = url.split("@")[-1].split("/")[0] if "@" in url else "(unknown)"
    print(f"Connecting to host: {host}")
    print(f"sslmode in URL: {'sslmode=' in url.lower()}")

    try:
        with connect() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT version(), current_database(), current_user")
                version, db, user = cur.fetchone()
                print(f"OK — database={db}, user={user}")
                print(f"Postgres: {version.split(',')[0]}")

                cur.execute("SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'postgis')")
                has_postgis = cur.fetchone()[0]
                print(f"PostGIS extension: {'yes' if has_postgis else 'no'}")

                cur.execute(
                    """
                    SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = 'ccc'
                    ORDER BY table_name
                    """
                )
                tables = [r[0] for r in cur.fetchall()]
                print(f"ccc tables: {tables or '(none yet)'}")
        return 0
    except Exception as ex:
        print(f"FAILED: {type(ex).__name__}: {ex}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
