CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS ccc;

-- Recreate so geometry type changes apply (Point / Polygon, not Multi*)
DROP TABLE IF EXISTS ccc.rating_unit;
DROP TABLE IF EXISTS ccc.street_address;
DROP TABLE IF EXISTS ccc.park;
DROP TABLE IF EXISTS ccc.place_name;

CREATE TABLE ccc.place_name (
    place_name_id INTEGER PRIMARY KEY,
    place_name TEXT,
    display_place_name TEXT,
    locality TEXT,
    geom geometry(Point, 4326) NOT NULL,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX place_name_geom_idx
    ON ccc.place_name USING GIST (geom);

CREATE TABLE ccc.park (
    park_id INTEGER PRIMARY KEY,
    greenspace_park_id INTEGER,
    park_name TEXT,
    park_type_description TEXT,
    geom geometry(Polygon, 4326) NOT NULL,
    center_point geometry(Point, 4326) NOT NULL,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX park_geom_idx
    ON ccc.park USING GIST (geom);

CREATE INDEX park_center_point_idx
    ON ccc.park USING GIST (center_point);

CREATE TABLE ccc.street_address (
    street_address_id INTEGER PRIMARY KEY,
    street_address TEXT,
    locality_name TEXT,
    post_code TEXT,
    street_address_status_description TEXT,
    occupation_level_description TEXT,
    geom geometry(Point, 4326) NOT NULL,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX street_address_geom_idx
    ON ccc.street_address USING GIST (geom);

CREATE INDEX street_address_locality_idx
    ON ccc.street_address (locality_name);

CREATE TABLE ccc.rating_unit (
    rating_unit_id INTEGER PRIMARY KEY,
    street_address_id INTEGER,
    occupation_level_description TEXT,
    street_address TEXT,
    locality_name TEXT,
    geom geometry(Polygon, 4326) NOT NULL,
    center_point geometry(Point, 4326) NOT NULL,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX rating_unit_geom_idx
    ON ccc.rating_unit USING GIST (geom);

CREATE INDEX rating_unit_center_point_idx
    ON ccc.rating_unit USING GIST (center_point);

CREATE INDEX rating_unit_street_address_id_idx
    ON ccc.rating_unit (street_address_id);
