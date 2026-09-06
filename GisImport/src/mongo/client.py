from __future__ import annotations

from pymongo import MongoClient
from pymongo.database import Database

from src.mongo.config import MONGO_DB, load_mongo_uri


def connect(uri: str | None = None, *, server_selection_timeout_ms: int = 20000) -> MongoClient:
    return MongoClient(
        uri or load_mongo_uri(),
        serverSelectionTimeoutMS=server_selection_timeout_ms,
    )


def get_database(client: MongoClient | None = None, db_name: str | None = None) -> Database:
    owns_client = client is None
    client = client or connect()
    db = client[db_name or MONGO_DB]
    # Touch to fail fast when caller only needs the Database handle briefly
    if owns_client:
        client.admin.command("ping")
    return db
