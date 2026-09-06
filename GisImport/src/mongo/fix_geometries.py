from __future__ import annotations

import argparse
import sys
from typing import Any

from pymongo import UpdateOne
from pymongo.collection import Collection

from src.mongo.config import (
    MONGO_BATCH_SIZE,
    MONGO_DB,
    MONGO_DEFAULT_COLLECTIONS,
)
from src.geometry import normalize_geojson_geometry
from src.mongo.client import connect

MULTI_TYPES = ("MultiPoint", "MultiPolygon")
SAMPLE_LIMIT = 3


def _fix_collection(
    col: Collection,
    *,
    apply: bool,
    batch_size: int,
    sample_limit: int = SAMPLE_LIMIT,
) -> dict[str, int]:
    query = {"geometry.type": {"$in": list(MULTI_TYPES)}}
    total = col.count_documents(query)
    stats = {
        "matched": total,
        "updated": 0,
        "would_update": 0,
        "skipped": 0,
        "errors": 0,
    }

    if total == 0:
        print(f"  {col.name}: no MultiPoint/MultiPolygon documents")
        return stats

    print(f"  {col.name}: {total} document(s) with Multi* geometry")
    cursor = col.find(query, {"geometry": 1})
    ops: list[UpdateOne] = []
    samples_shown = 0

    for doc in cursor:
        try:
            geom = doc.get("geometry")
            if not isinstance(geom, dict):
                stats["skipped"] += 1
                continue
            old_type = geom.get("type")
            new_geom = normalize_geojson_geometry(geom)
            if new_geom is None:
                stats["skipped"] += 1
                continue

            if samples_shown < sample_limit:
                samples_shown += 1
                print(
                    f"    sample {_id_preview(doc)}: {old_type} -> {new_geom['type']}"
                )

            if apply:
                ops.append(UpdateOne({"_id": doc["_id"]}, {"$set": {"geometry": new_geom}}))
                if len(ops) >= batch_size:
                    result = col.bulk_write(ops, ordered=False)
                    stats["updated"] += result.modified_count
                    ops.clear()
            else:
                stats["would_update"] += 1
        except Exception as ex:  # noqa: BLE001
            stats["errors"] += 1
            print(f"    ERROR {_id_preview(doc)}: {ex}", file=sys.stderr)

    if apply and ops:
        result = col.bulk_write(ops, ordered=False)
        stats["updated"] += result.modified_count

    if apply:
        print(f"  {col.name} done: updated={stats['updated']}, errors={stats['errors']}")
    else:
        print(
            f"  {col.name} dry-run: would_update={stats['would_update']}, "
            f"errors={stats['errors']}"
        )
    return stats


def _id_preview(doc: dict[str, Any]) -> str:
    return str(doc.get("_id", "?"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Convert MongoDB MultiPoint/MultiPolygon geometries to Point/Polygon "
            "(first part). Dry-run by default."
        )
    )
    parser.add_argument(
        "--db",
        default=MONGO_DB,
        help=f"Database name (default: {MONGO_DB})",
    )
    parser.add_argument(
        "--collection",
        action="append",
        dest="collections",
        help="Collection to fix (repeatable). Default: place_names, street_addresses, parks, ratingunits",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write changes (default is dry-run)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=MONGO_BATCH_SIZE,
        help=f"bulk_write batch size (default: {MONGO_BATCH_SIZE})",
    )
    args = parser.parse_args(argv)

    collections = args.collections or list(MONGO_DEFAULT_COLLECTIONS)
    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"Mongo geometry fix [{mode}] db={args.db} collections={collections}")

    client = connect()
    try:
        client.admin.command("ping")
        db = client[args.db]
        totals = {"matched": 0, "updated": 0, "would_update": 0, "errors": 0}

        for name in collections:
            if name not in db.list_collection_names():
                print(f"  SKIP {name}: collection not found", file=sys.stderr)
                continue
            stats = _fix_collection(
                db[name],
                apply=args.apply,
                batch_size=args.batch_size,
            )
            for key in totals:
                totals[key] += stats[key]

        print(
            f"Finished [{mode}]. matched={totals['matched']}, "
            f"updated={totals['updated']}, would_update={totals['would_update']}, "
            f"errors={totals['errors']}"
        )
        return 1 if totals["errors"] else 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
