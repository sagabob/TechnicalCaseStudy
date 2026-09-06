from __future__ import annotations

from typing import Any

from shapely.geometry import MultiPoint, MultiPolygon, Point, Polygon
from shapely.geometry.base import BaseGeometry


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


def normalize_geojson_geometry(geom: dict[str, Any]) -> dict[str, Any] | None:
    """
    Unwrap MultiPoint → Point and MultiPolygon → Polygon (first part).

    Returns None if geometry is already Point/Polygon (no change needed).
    Raises ValueError for empty or unsupported types.
    """
    if not isinstance(geom, dict):
        raise ValueError("geometry must be an object")

    gtype = geom.get("type")
    coords = geom.get("coordinates")

    if gtype in ("Point", "Polygon"):
        return None

    if gtype == "MultiPoint":
        if not isinstance(coords, list) or len(coords) == 0:
            raise ValueError("Empty MultiPoint")
        return {"type": "Point", "coordinates": coords[0]}

    if gtype == "MultiPolygon":
        if not isinstance(coords, list) or len(coords) == 0:
            raise ValueError("Empty MultiPolygon")
        return {"type": "Polygon", "coordinates": coords[0]}

    raise ValueError(f"Unsupported geometry type: {gtype}")
