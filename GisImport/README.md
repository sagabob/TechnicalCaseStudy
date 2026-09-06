# GisImport — GeoJSON to Postgres

Import Christchurch Origin GeoJSON layers into **Postgres + PostGIS** (schema `ccc`).

| Layer folder | Table | Geometry | Extra |
|--------------|-------|----------|--------|
| `Data/Origin/vwPlaceName` | `ccc.place_name` | Point | — |
| `Data/Origin/vwPark` | `ccc.park` | Polygon | `center_point` (centroid) |
| `Data/Origin/vwStreetAddress` | `ccc.street_address` | Point | — |
| `Data/Origin/vwRatingUnit` | `ccc.rating_unit` | Polygon | `center_point` (centroid) |

Source MultiPoint / MultiPolygon features are normalised to Point / Polygon on import. For parks and rating units, `center_point` is set with `ST_Centroid(geom)`.

Approximate file counts (one feature per file): place_name ~2.1k, park ~1.1k, street_address ~183k, rating_unit ~169k.

## Prerequisites

- Python 3.11+
- Postgres with **PostGIS**
- A database already created (e.g. `gis` / `gisimport`)
- Cloud hosts (e.g. Aiven): TLS — `sslmode=require` is appended automatically if missing from `DATABASE_URL`

## Setup

```powershell
cd GisImport

python -m venv .venv
.\.venv\Scripts\Activate.ps1

pip install -r requirements.txt

Copy-Item .env.example .env
# Edit .env — set DATABASE_URL, e.g.
# DATABASE_URL=postgresql://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require
```

Optional: check connectivity before importing:

```powershell
python -m scripts.check_connection
```

## Schema and functions

Schema is **not** applied by default. Recreating schema **drops all four tables**.

```powershell
# Create / recreate tables only
python -m src.import_geojson --schema-only

# Apply spatial helper functions only
python -m src.import_geojson --functions-only
```

## Run import

Upserts into existing tables (safe to re-run; conflict on primary keys):

```powershell
cd GisImport
.\.venv\Scripts\Activate.ps1

# All layers
python -m src.import_geojson

# One layer at a time
python -m src.import_geojson --layer place_name
python -m src.import_geojson --layer park
python -m src.import_geojson --layer street_address
python -m src.import_geojson --layer rating_unit
```

### First-time / after schema changes

```powershell
python -m src.import_geojson --schema-only
python -m src.import_geojson --layer place_name
python -m src.import_geojson --layer park
python -m src.import_geojson --layer street_address
python -m src.import_geojson --layer rating_unit
python -m src.import_geojson --functions-only
```

Or recreate schema then import everything in one go:

```powershell
python -m src.import_geojson --apply-schema --apply-functions
```

### CLI flags

| Flag | Effect |
|------|--------|
| `--layer {all,place_name,park,street_address,rating_unit}` | Which layer to import (default: `all`) |
| `--apply-schema` | Run `sql/001_schema.sql` before import (destructive) |
| `--schema-only` | Apply schema only; no import |
| `--apply-functions` | Apply `sql/002_spatial_functions.sql` before import |
| `--functions-only` | Apply functions only; no import |

## Spatial SQL functions

Distances use geography (metres). Park / rating-unit **nearest** helpers use `center_point`; **containing** helpers use the polygon `geom`.

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

Example:

```sql
SELECT * FROM ccc.nearest_parks(172.6362, -43.5321, 1000, 10);
SELECT * FROM ccc.nearest_place_names(172.6362, -43.5321, 500, 10);
SELECT * FROM ccc.nearest_street_addresses(172.6362, -43.5321, 200, 10);
SELECT * FROM ccc.parks_containing_point(172.6362, -43.5321);
```

## Verify

```sql
SELECT PostGIS_Version();

SELECT COUNT(*) AS place_names FROM ccc.place_name;
SELECT COUNT(*) AS parks FROM ccc.park;
SELECT COUNT(*) AS street_addresses FROM ccc.street_address;
SELECT COUNT(*) AS rating_units FROM ccc.rating_unit;

SELECT place_name_id, place_name, locality, ST_AsText(geom)
FROM ccc.place_name
ORDER BY place_name_id
LIMIT 5;

SELECT park_id, park_name, ST_GeometryType(geom), ST_AsText(center_point)
FROM ccc.park
ORDER BY park_id
LIMIT 5;

SELECT street_address_id, street_address, locality_name, ST_AsText(geom)
FROM ccc.street_address
ORDER BY street_address_id
LIMIT 5;

SELECT rating_unit_id, street_address, ST_GeometryType(geom), ST_AsText(center_point)
FROM ccc.rating_unit
ORDER BY rating_unit_id
LIMIT 5;
```

From PowerShell:

```powershell
psql $env:DATABASE_URL -c "SELECT COUNT(*) FROM ccc.place_name; SELECT COUNT(*) FROM ccc.park;"
```

## Layout

```
GisImport/
├── .env.example
├── requirements.txt
├── README.md
├── Data/Origin/                 # GeoJSON source files
├── sql/
│   ├── 001_schema.sql           # PostGIS + ccc tables
│   └── 002_spatial_functions.sql
├── scripts/
│   └── check_connection.py
└── src/
    ├── config.py
    ├── db.py
    └── import_geojson.py
```
