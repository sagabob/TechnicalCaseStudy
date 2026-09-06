"""MongoDB settings for CCC GIS collections."""
from __future__ import annotations

import os

from src.config import PROJECT_ROOT  # noqa: F401 — loads .env via src.config

_ = PROJECT_ROOT  # referenced so dotenv load is intentional

MONGO_DB = os.getenv("MONGO_DB", "ccc_db")
MONGO_BATCH_SIZE = int(os.getenv("MONGO_BATCH_SIZE", "500"))
MONGO_DEFAULT_COLLECTIONS = tuple(
    c.strip()
    for c in os.getenv(
        "MONGO_COLLECTIONS",
        "place_names,street_addresses,parks,ratingunits",
    ).split(",")
    if c.strip()
)


def load_mongo_uri() -> str:
    """Load MONGO_URI from GisImport/.env or the process environment."""
    uri = os.getenv("MONGO_URI", "").strip()
    if not uri:
        raise RuntimeError(
            "MONGO_URI is not set. Copy .env.example to .env and set your MongoDB URI."
        )
    return uri
