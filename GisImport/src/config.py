from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent

load_dotenv(PROJECT_ROOT / ".env")

# Paths (override with env if needed)
DATA_ORIGIN = Path(
    os.getenv("DATA_ORIGIN", str(PROJECT_ROOT / "Data" / "Origin"))
).resolve()
SCHEMA_SQL = Path(
    os.getenv("SCHEMA_SQL", str(PROJECT_ROOT / "sql" / "001_schema.sql"))
).resolve()
FUNCTIONS_SQL = Path(
    os.getenv("FUNCTIONS_SQL", str(PROJECT_ROOT / "sql" / "002_spatial_functions.sql"))
).resolve()

# Database naming / geometry defaults
DB_SCHEMA = os.getenv("DB_SCHEMA", "ccc")
GEOMETRY_SRID = int(os.getenv("GEOMETRY_SRID", "4326"))
GEOJSON_GLOB = os.getenv("GEOJSON_GLOB", "*.geojson")
COMMIT_EVERY = int(os.getenv("COMMIT_EVERY", "200"))


@dataclass(frozen=True)
class LayerConfig:
    """One Origin folder → one target table."""

    key: str
    folder: str
    id_property: str
    geom_kind: Literal["point", "polygon"]
    # Maps upsert kwarg → GeoJSON property name
    field_map: dict[str, str]
    # Param names (keys in field_map) stored as integers
    int_params: frozenset[str] = frozenset()


LAYERS: dict[str, LayerConfig] = {
    "place_name": LayerConfig(
        key="place_name",
        folder=os.getenv("PLACE_NAME_FOLDER", "vwPlaceName"),
        id_property="PlaceNameID",
        geom_kind="point",
        field_map={
            "place_name": "PlaceName",
            "display_place_name": "DisplayPlaceName",
            "locality": "Locality",
        },
    ),
    "park": LayerConfig(
        key="park",
        folder=os.getenv("PARK_FOLDER", "vwPark"),
        id_property="ParkID",
        geom_kind="polygon",
        field_map={
            "greenspace_park_id": "GreenspaceParkID",
            "park_name": "ParkName",
            "park_type_description": "ParkTypeDescription",
        },
        int_params=frozenset({"greenspace_park_id"}),
    ),
    "street_address": LayerConfig(
        key="street_address",
        folder=os.getenv("STREET_ADDRESS_FOLDER", "vwStreetAddress"),
        id_property="StreetAddressID",
        geom_kind="point",
        field_map={
            "street_address": "StreetAddress",
            "locality_name": "LocalityName",
            "post_code": "PostCode",
            "street_address_status_description": "StreetAddressStatusDescription",
            "occupation_level_description": "OccupationLevelDescription",
        },
    ),
    "rating_unit": LayerConfig(
        key="rating_unit",
        folder=os.getenv("RATING_UNIT_FOLDER", "vwRatingUnit"),
        id_property="RatingUnitID",
        geom_kind="polygon",
        field_map={
            "street_address_id": "StreetAddressID",
            "occupation_level_description": "OccupationLevelDescription",
            "street_address": "StreetAddress",
            "locality_name": "LocalityName",
        },
        int_params=frozenset({"street_address_id"}),
    ),
}


def layer_dir(layer: LayerConfig) -> Path:
    return DATA_ORIGIN / layer.folder


def load_database_url() -> str:
    """Load DATABASE_URL from GisImport/.env or the process environment."""
    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError(
            "DATABASE_URL is not set. Copy .env.example to .env and set your Postgres URL."
        )
    # Aiven and most cloud Postgres require TLS
    if "sslmode=" not in url.lower():
        sep = "&" if "?" in url else "?"
        url = f"{url}{sep}sslmode=require"
    return url
