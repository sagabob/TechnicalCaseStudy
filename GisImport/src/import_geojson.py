from __future__ import annotations

import argparse
import sys
from typing import Any, Callable

from src.config import (
    COMMIT_EVERY,
    DATA_ORIGIN,
    FUNCTIONS_SQL,
    GEOJSON_GLOB,
    LAYERS,
    LayerConfig,
    SCHEMA_SQL,
    layer_dir,
)
from src.db import (
    apply_functions,
    apply_schema,
    connect,
    parse_feature_geometry,
    read_geojson,
    upsert_park,
    upsert_place_name,
    upsert_rating_unit,
    upsert_street_address,
)

UpsertFn = Callable[..., None]

UPSERT_BY_LAYER: dict[str, UpsertFn] = {
    "place_name": upsert_place_name,
    "park": upsert_park,
    "street_address": upsert_street_address,
    "rating_unit": upsert_rating_unit,
}

ID_PARAM_BY_LAYER: dict[str, str] = {
    "place_name": "place_name_id",
    "park": "park_id",
    "street_address": "street_address_id",
    "rating_unit": "rating_unit_id",
}


def _iter_geojson(folder):
    if not folder.is_dir():
        return []
    return sorted(folder.glob(GEOJSON_GLOB))


def _optional_int(value: Any) -> int | None:
    if value is None:
        return None
    return int(value)


def _props_for_upsert(layer: LayerConfig, props: dict[str, Any]) -> dict[str, Any]:
    """Map GeoJSON properties → upsert kwargs using layer.field_map."""
    mapped: dict[str, Any] = {}
    for param, prop_name in layer.field_map.items():
        raw = props.get(prop_name)
        if param in layer.int_params:
            mapped[param] = _optional_int(raw)
        else:
            mapped[param] = raw
    return mapped


def import_layer(conn, layer: LayerConfig) -> tuple[int, int]:
    folder = layer_dir(layer)
    upsert = UPSERT_BY_LAYER[layer.key]
    id_param = ID_PARAM_BY_LAYER[layer.key]

    ok = 0
    errors = 0
    files = _iter_geojson(folder)
    total = len(files)

    for i, path in enumerate(files, start=1):
        try:
            collection = read_geojson(path)
            features = collection.get("features") or []
            if not features:
                continue
            for feature in features:
                props = feature.get("properties") or {}
                raw_id = props.get(layer.id_property)
                if raw_id is None:
                    raise ValueError(f"Missing {layer.id_property}")
                geom = parse_feature_geometry(feature)
                kwargs = _props_for_upsert(layer, props)
                kwargs[id_param] = int(raw_id)
                kwargs["geom"] = geom
                upsert(conn, **kwargs)
                ok += 1
            if i % COMMIT_EVERY == 0 or i == total:
                conn.commit()
                print(f"  {layer.key}: {i}/{total} files ({ok} features)")
        except Exception as ex:  # noqa: BLE001 — log and continue per file
            errors += 1
            print(f"  ERROR {path.name}: {ex}", file=sys.stderr)

    conn.commit()
    return ok, errors


def main(argv: list[str] | None = None) -> int:
    layer_keys = list(LAYERS.keys())
    parser = argparse.ArgumentParser(
        description="Import Origin GeoJSON layers into Postgres/PostGIS."
    )
    parser.add_argument(
        "--layer",
        choices=["all", *layer_keys],
        default="all",
        help="Which layer to import (default: all)",
    )
    parser.add_argument(
        "--apply-schema",
        action="store_true",
        help=f"Run {SCHEMA_SQL.name} before import (drops and recreates tables)",
    )
    parser.add_argument(
        "--apply-functions",
        action="store_true",
        help=f"Apply spatial functions/procedures from {FUNCTIONS_SQL.name}",
    )
    parser.add_argument(
        "--functions-only",
        action="store_true",
        help=f"Only apply {FUNCTIONS_SQL.name} (no schema recreate, no data import)",
    )
    parser.add_argument(
        "--schema-only",
        action="store_true",
        help=f"Only apply {SCHEMA_SQL.name} (no functions, no data import)",
    )
    args = parser.parse_args(argv)

    if args.functions_only and args.schema_only:
        parser.error("Use only one of --functions-only or --schema-only")

    print(f"Data root: {DATA_ORIGIN}")
    with connect() as conn:
        if args.functions_only:
            print(f"Applying functions from {FUNCTIONS_SQL}...")
            apply_functions(conn)
            print("Functions ready.")
            return 0

        if args.schema_only:
            print(f"Applying schema from {SCHEMA_SQL}...")
            apply_schema(conn)
            print("Schema ready.")
            return 0

        if args.apply_schema:
            print(f"Applying schema from {SCHEMA_SQL}...")
            apply_schema(conn)
            print("Schema ready.")

        if args.apply_functions:
            print(f"Applying functions from {FUNCTIONS_SQL}...")
            apply_functions(conn)
            print("Functions ready.")

        selected = layer_keys if args.layer == "all" else [args.layer]
        total_ok = 0
        total_err = 0

        for key in selected:
            layer = LAYERS[key]
            folder = layer_dir(layer)
            print(f"Importing {key} from {folder}...")
            ok, err = import_layer(conn, layer)
            total_ok += ok
            total_err += err
            print(f"{key} done: {ok} upserted, {err} file errors")

    print(f"Finished. Features upserted={total_ok}, file errors={total_err}")
    return 1 if total_err else 0


if __name__ == "__main__":
    raise SystemExit(main())
