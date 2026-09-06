# GisImport — GeoJSON to Postgres / Mongo tools

Import Christchurch Origin GeoJSON into **Postgres + PostGIS** (schema `ccc`), and fix Multi* geometries in **MongoDB** (`ccc_db`).

| Layer folder | Postgres table | Mongo collection | Geometry |
|--------------|----------------|------------------|----------|
| `data/Origin/vwPlaceName` | `ccc.place_name` | `place_names` | Point (`center_point` N/A) |
| `data/Origin/vwPark` | `ccc.park` | `parks` | Polygon + `center_point` (Postgres) |
| `data/Origin/vwStreetAddress` | `ccc.street_address` | `street_addresses` | Point |
| `data/Origin/vwRatingUnit` | `ccc.rating_unit` | `ratingunits` | Polygon + `center_point` (Postgres) |

Source MultiPoint / MultiPolygon features are normalised to Point / Polygon (first part). Parks and rating units get `center_point` via `ST_Centroid(geom)` in Postgres.

## Prerequisites

- Python 3.11+
- Postgres with **PostGIS** (for import)
- MongoDB reachable via `MONGO_URI` (for Mongo tools)
- A database already created (e.g. `gis` / `gisimport`)

Cloud Postgres (e.g. Aiven): `sslmode=require` is appended automatically if missing from `DATABASE_URL`.

## Setup

```powershell
cd GisImport

python -m venv .venv
.\.venv\Scripts\Activate.ps1

pip install -r requirements.txt

Copy-Item .env.example .env
# Set DATABASE_URL and/or MONGO_URI
```

Connectivity checks:

```powershell
python -m scripts.postgres.check_connection
python -m scripts.mongo.check_connection
```

Optional Postgres schema helper (same as `--schema-only`; destructive):

```powershell
python -m scripts.postgres.create_schema
```

## Postgres schema and functions

Schema is **not** applied by default. Recreating schema **drops all four tables**.

```powershell
python -m src.postgres.import_geojson --schema-only
python -m src.postgres.import_geojson --functions-only
```

## Postgres import

```powershell
cd GisImport
.\.venv\Scripts\Activate.ps1

# All layers
python -m src.postgres.import_geojson

# One layer
python -m src.postgres.import_geojson --layer place_name
python -m src.postgres.import_geojson --layer park
python -m src.postgres.import_geojson --layer street_address
python -m src.postgres.import_geojson --layer rating_unit
```

### First-time / after schema changes

```powershell
python -m src.postgres.import_geojson --schema-only
python -m src.postgres.import_geojson --layer place_name
python -m src.postgres.import_geojson --layer park
python -m src.postgres.import_geojson --layer street_address
python -m src.postgres.import_geojson --layer rating_unit
python -m src.postgres.import_geojson --functions-only
```

Or:

```powershell
python -m src.postgres.import_geojson --apply-schema --apply-functions
```

### CLI flags

| Flag | Effect |
|------|--------|
| `--layer {all,place_name,park,street_address,rating_unit}` | Which layer (default: `all`) |
| `--apply-schema` | Run `sql/001_schema.sql` before import (destructive) |
| `--schema-only` | Apply schema only |
| `--apply-functions` | Apply `sql/002_spatial_functions.sql` before import |
| `--functions-only` | Apply functions only |

## Fix Mongo geometries

Convert `MultiPoint` → `Point` and `MultiPolygon` → `Polygon` on `geometry` (first part if multi).

Default collections: `place_names`, `street_addresses`, `parks`, `ratingunits`.

```powershell
# Dry-run (default) — counts + sample conversions, no writes
python -m src.mongo.fix_geometries

# Apply updates
python -m src.mongo.fix_geometries --apply

# One collection
python -m src.mongo.fix_geometries --collection parks --apply
```

## Spatial SQL functions

Distances use geography (metres). Park / rating-unit **nearest** helpers use `center_point`; **containing** helpers use polygon `geom`.

| Function | Purpose |
|----------|---------|
| `ccc.nearest_parks(lon, lat, radius_m, limit)` | Parks within radius, nearest first |
| `ccc.parks_containing_point(lon, lat)` | Parks whose polygon contains the point |
| `ccc.distance_to_park_m(lon, lat, park_id)` | Distance (m) to one park centroid |
| `ccc.nearest_place_names(lon, lat, radius_m, limit)` | Place names within radius |
| `ccc.distance_to_place_name_m(lon, lat, id)` | Distance (m) to one place name |
| `ccc.place_names_by_locality(locality, limit)` | Filter place names by locality |
| `ccc.nearest_street_addresses(lon, lat, radius_m, limit)` | Street addresses within radius |
| `ccc.nearest_rating_units(lon, lat, radius_m, limit)` | Rating units within radius (by centroid) |
| `ccc.rating_units_containing_point(lon, lat)` | Rating unit polygon contains point |

```sql
SELECT * FROM ccc.nearest_parks(172.6362, -43.5321, 1000, 10);
SELECT * FROM ccc.nearest_street_addresses(172.6362, -43.5321, 200, 10);
```

## Verify (Postgres)

```sql
SELECT COUNT(*) FROM ccc.place_name;
SELECT COUNT(*) FROM ccc.park;
SELECT park_id, park_name, ST_AsText(center_point) FROM ccc.park LIMIT 5;
```

## Layout

```
GisImport/
├── .env.example
├── requirements.txt
├── README.md
├── data/Origin/                 # GeoJSON source files
├── sql/
│   ├── 001_schema.sql
│   └── 002_spatial_functions.sql
├── scripts/
│   ├── postgres/
│   │   ├── check_connection.py
│   │   └── create_schema.py
│   └── mongo/
│       └── check_connection.py
└── src/
    ├── config.py                # PROJECT_ROOT + .env load
    ├── geometry.py              # Multi* → Point/Polygon
    ├── postgres/
    │   ├── config.py
    │   ├── db.py
    │   └── import_geojson.py
    └── mongo/
        ├── config.py
        ├── client.py
        └── fix_geometries.py
```
