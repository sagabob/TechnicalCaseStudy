"""Quick Mongo connectivity check + geometry type counts (no secrets printed)."""
from __future__ import annotations

import sys

from src.mongo.config import MONGO_DB, MONGO_DEFAULT_COLLECTIONS, load_mongo_uri
from src.mongo.client import connect


def main() -> int:
    uri = load_mongo_uri()
    # Host only - strip credentials
    host = uri.split("@")[-1].split("/")[0] if "@" in uri else "(unknown)"
    print(f"Connecting to host: {host}")
    print(f"Database: {MONGO_DB}")

    try:
        client = connect()
        try:
            client.admin.command("ping")
            db = client[MONGO_DB]
            names = sorted(db.list_collection_names())
            print(f"OK - collections: {names}")

            for name in MONGO_DEFAULT_COLLECTIONS:
                if name not in names:
                    print(f"  {name}: (missing)")
                    continue
                col = db[name]
                counts = {}
                for gtype in ("MultiPoint", "MultiPolygon", "Point", "Polygon"):
                    n = col.count_documents({"geometry.type": gtype})
                    if n:
                        counts[gtype] = n
                print(f"  {name}: {col.estimated_document_count()} docs, types={counts}")
        finally:
            client.close()
        return 0
    except Exception as ex:
        print(f"FAILED: {type(ex).__name__}: {ex}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
