# TechnicalCaseStudy

Case-study workspace focused on Christchurch GIS data tooling.

## Projects

| Project | Description |
|---------|-------------|
| [GisImport](GisImport/) | Import Origin GeoJSON into **Postgres/PostGIS**, and normalise Multi* geometries in **MongoDB** |

Detailed setup, CLI flags, and SQL helpers: **[GisImport/README.md](GisImport/README.md)**.

## GisImport (quick start)

```powershell
cd GisImport
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
# Set DATABASE_URL and/or MONGO_URI in .env
```

**Postgres**

```powershell
python -m scripts.postgres.check_connection
python -m src.postgres.import_geojson --schema-only
python -m src.postgres.import_geojson --layer place_name
python -m src.postgres.import_geojson --functions-only
```

Schema is opt-in (`--apply-schema` / `--schema-only`); default import does not drop tables.

**Mongo**

```powershell
python -m scripts.mongo.check_connection
python -m src.mongo.fix_geometries          # dry-run
python -m src.mongo.fix_geometries --apply  # write Point/Polygon
```

Default Mongo collections: `place_names`, `street_addresses`, `parks`, `ratingunits`.

## Data layout

| Source folder | Postgres (`ccc`) | Mongo (`ccc_db`) |
|---------------|------------------|------------------|
| `GisImport/data/Origin/vwPlaceName` | `place_name` | `place_names` |
| `GisImport/data/Origin/vwPark` | `park` | `parks` |
| `GisImport/data/Origin/vwStreetAddress` | `street_address` | `street_addresses` |
| `GisImport/data/Origin/vwRatingUnit` | `rating_unit` | `ratingunits` |

Large `data/` dumps (`.geojson`, `.json`, `.zip`) are gitignored — keep them locally under `GisImport/data/`.

## Repo layout

```
TechnicalCaseStudy/
├── README.md
├── GisImport/          # GIS import + Mongo fix tools
└── .github/workflows/  # CI / infra workflows
```
