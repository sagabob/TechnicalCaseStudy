from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import psycopg
from shapely.geometry import MultiPoint, MultiPolygon, Point, Polygon, mapping, shape
from shapely.geometry.base import BaseGeometry

from src.config import (
    DB_SCHEMA,
    FUNCTIONS_SQL,
    GEOMETRY_SRID,
    SCHEMA_SQL,
    load_database_url,
)


def connect() -> psycopg.Connection:
    return psycopg.connect(load_database_url())


def apply_sql_file(conn: psycopg.Connection, path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"SQL file not found: {path}")
    sql = path.read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def apply_schema(conn: psycopg.Connection) -> None:
    apply_sql_file(conn, SCHEMA_SQL)


def apply_functions(conn: psycopg.Connection) -> None:
    """Create/replace spatial functions and stored procedures."""
    apply_sql_file(conn, FUNCTIONS_SQL)


def _geom_geojson(geom: BaseGeometry) -> str:
    """Serialize Shapely geometry to GeoJSON text for ST_GeomFromGeoJSON."""
    return json.dumps(mapping(geom))


def as_point(geom: BaseGeometry) -> Point:
    """Normalize GeoJSON MultiPoint/Point to a single Point."""
    if isinstance(geom, Point):
        return geom
    if isinstance(geom, MultiPoint):
        if geom.is_empty or len(geom.geoms) == 0:
            raise ValueError("Empty MultiPoint")
        return geom.geoms[0]
    raise ValueError(f"Expected Point or MultiPoint, got {geom.geom_type}")


def as_polygon(geom: BaseGeometry) -> Polygon:
    """Normalize GeoJSON MultiPolygon/Polygon to a single Polygon (first part if multi)."""
    if isinstance(geom, Polygon):
        return geom
    if isinstance(geom, MultiPolygon):
        if geom.is_empty or len(geom.geoms) == 0:
            raise ValueError("Empty MultiPolygon")
        return geom.geoms[0]
    raise ValueError(f"Expected Polygon or MultiPolygon, got {geom.geom_type}")


def upsert_place_name(
    conn: psycopg.Connection,
    *,
    place_name_id: int,
    place_name: str | None,
    display_place_name: str | None,
    locality: str | None,
    geom: BaseGeometry,
) -> None:
    point = as_point(geom)
    geojson = _geom_geojson(point)
    with conn.cursor() as cur:
        cur.execute(
            f"""
            INSERT INTO {DB_SCHEMA}.place_name (
                place_name_id, place_name, display_place_name, locality,
                geom, imported_at
            )
            VALUES (
                %(place_name_id)s, %(place_name)s, %(display_place_name)s, %(locality)s,
                ST_SetSRID(ST_GeomFromGeoJSON(%(geojson)s), %(srid)s),
                now()
            )
            ON CONFLICT (place_name_id) DO UPDATE SET
                place_name = EXCLUDED.place_name,
                display_place_name = EXCLUDED.display_place_name,
                locality = EXCLUDED.locality,
                geom = EXCLUDED.geom,
                imported_at = now()
            """,
            {
                "place_name_id": place_name_id,
                "place_name": place_name,
                "display_place_name": display_place_name,
                "locality": locality,
                "geojson": geojson,
                "srid": GEOMETRY_SRID,
            },
        )


def upsert_park(
    conn: psycopg.Connection,
    *,
    park_id: int,
    greenspace_park_id: int | None,
    park_name: str | None,
    park_type_description: str | None,
    geom: BaseGeometry,
) -> None:
    polygon = as_polygon(geom)
    geojson = _geom_geojson(polygon)
    with conn.cursor() as cur:
        cur.execute(
            f"""
            INSERT INTO {DB_SCHEMA}.park (
                park_id, greenspace_park_id, park_name, park_type_description,
                geom, center_point, imported_at
            )
            VALUES (
                %(park_id)s, %(greenspace_park_id)s, %(park_name)s, %(park_type_description)s,
                ST_SetSRID(ST_GeomFromGeoJSON(%(geojson)s), %(srid)s),
                ST_Centroid(ST_SetSRID(ST_GeomFromGeoJSON(%(geojson)s), %(srid)s)),
                now()
            )
            ON CONFLICT (park_id) DO UPDATE SET
                greenspace_park_id = EXCLUDED.greenspace_park_id,
                park_name = EXCLUDED.park_name,
                park_type_description = EXCLUDED.park_type_description,
                geom = EXCLUDED.geom,
                center_point = EXCLUDED.center_point,
                imported_at = now()
            """,
            {
                "park_id": park_id,
                "greenspace_park_id": greenspace_park_id,
                "park_name": park_name,
                "park_type_description": park_type_description,
                "geojson": geojson,
                "srid": GEOMETRY_SRID,
            },
        )


def upsert_street_address(
    conn: psycopg.Connection,
    *,
    street_address_id: int,
    street_address: str | None,
    locality_name: str | None,
    post_code: str | None,
    street_address_status_description: str | None,
    occupation_level_description: str | None,
    geom: BaseGeometry,
) -> None:
    point = as_point(geom)
    geojson = _geom_geojson(point)
    with conn.cursor() as cur:
        cur.execute(
            f"""
            INSERT INTO {DB_SCHEMA}.street_address (
                street_address_id, street_address, locality_name, post_code,
                street_address_status_description, occupation_level_description,
                geom, imported_at
            )
            VALUES (
                %(street_address_id)s, %(street_address)s, %(locality_name)s, %(post_code)s,
                %(street_address_status_description)s, %(occupation_level_description)s,
                ST_SetSRID(ST_GeomFromGeoJSON(%(geojson)s), %(srid)s),
                now()
            )
            ON CONFLICT (street_address_id) DO UPDATE SET
                street_address = EXCLUDED.street_address,
                locality_name = EXCLUDED.locality_name,
                post_code = EXCLUDED.post_code,
                street_address_status_description = EXCLUDED.street_address_status_description,
                occupation_level_description = EXCLUDED.occupation_level_description,
                geom = EXCLUDED.geom,
                imported_at = now()
            """,
            {
                "street_address_id": street_address_id,
                "street_address": street_address,
                "locality_name": locality_name,
                "post_code": post_code,
                "street_address_status_description": street_address_status_description,
                "occupation_level_description": occupation_level_description,
                "geojson": geojson,
                "srid": GEOMETRY_SRID,
            },
        )


def upsert_rating_unit(
    conn: psycopg.Connection,
    *,
    rating_unit_id: int,
    street_address_id: int | None,
    occupation_level_description: str | None,
    street_address: str | None,
    locality_name: str | None,
    geom: BaseGeometry,
) -> None:
    polygon = as_polygon(geom)
    geojson = _geom_geojson(polygon)
    with conn.cursor() as cur:
        cur.execute(
            f"""
            INSERT INTO {DB_SCHEMA}.rating_unit (
                rating_unit_id, street_address_id, occupation_level_description,
                street_address, locality_name, geom, center_point, imported_at
            )
            VALUES (
                %(rating_unit_id)s, %(street_address_id)s, %(occupation_level_description)s,
                %(street_address)s, %(locality_name)s,
                ST_SetSRID(ST_GeomFromGeoJSON(%(geojson)s), %(srid)s),
                ST_Centroid(ST_SetSRID(ST_GeomFromGeoJSON(%(geojson)s), %(srid)s)),
                now()
            )
            ON CONFLICT (rating_unit_id) DO UPDATE SET
                street_address_id = EXCLUDED.street_address_id,
                occupation_level_description = EXCLUDED.occupation_level_description,
                street_address = EXCLUDED.street_address,
                locality_name = EXCLUDED.locality_name,
                geom = EXCLUDED.geom,
                center_point = EXCLUDED.center_point,
                imported_at = now()
            """,
            {
                "rating_unit_id": rating_unit_id,
                "street_address_id": street_address_id,
                "occupation_level_description": occupation_level_description,
                "street_address": street_address,
                "locality_name": locality_name,
                "geojson": geojson,
                "srid": GEOMETRY_SRID,
            },
        )


def parse_feature_geometry(feature: dict[str, Any]) -> BaseGeometry:
    geom_obj = feature.get("geometry")
    if not geom_obj:
        raise ValueError("Feature has no geometry")
    return shape(geom_obj)


def read_geojson(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))
