-- Spatial helper functions for ccc.place_name and ccc.park
-- Distances use geography (metres). Apply after 001_schema.sql:
--   psql "$DATABASE_URL" -f sql/002_spatial_functions.sql

-- ---------------------------------------------------------------------------
-- Parks
-- ---------------------------------------------------------------------------

-- Parks within radius_m of (lon, lat), nearest first
CREATE OR REPLACE FUNCTION ccc.nearest_parks(
    lon double precision,
    lat double precision,
    radius_m double precision DEFAULT 1000,
    result_limit integer DEFAULT 20
)
RETURNS TABLE (
    park_id integer,
    park_name text,
    park_type_description text,
    distance_m double precision
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        p.park_id,
        p.park_name,
        p.park_type_description,
        ST_Distance(
            p.center_point::geography,
            ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
        ) AS distance_m
    FROM ccc.park AS p
    WHERE ST_DWithin(
        p.center_point::geography,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
        radius_m
    )
    ORDER BY distance_m
    LIMIT result_limit;
$$;

-- Parks whose polygon contains the point (lon, lat)
CREATE OR REPLACE FUNCTION ccc.parks_containing_point(
    lon double precision,
    lat double precision
)
RETURNS TABLE (
    park_id integer,
    park_name text,
    park_type_description text
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        p.park_id,
        p.park_name,
        p.park_type_description
    FROM ccc.park AS p
    WHERE ST_Contains(
        p.geom,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)
    );
$$;

-- Distance (metres) from a point to a specific park
CREATE OR REPLACE FUNCTION ccc.distance_to_park_m(
    lon double precision,
    lat double precision,
    p_park_id integer
)
RETURNS double precision
LANGUAGE sql
STABLE
AS $$
    SELECT ST_Distance(
        p.center_point::geography,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
    )
    FROM ccc.park AS p
    WHERE p.park_id = p_park_id;
$$;

-- ---------------------------------------------------------------------------
-- Place names
-- ---------------------------------------------------------------------------

-- Place names within radius_m of (lon, lat), nearest first
CREATE OR REPLACE FUNCTION ccc.nearest_place_names(
    lon double precision,
    lat double precision,
    radius_m double precision DEFAULT 1000,
    result_limit integer DEFAULT 20
)
RETURNS TABLE (
    place_name_id integer,
    place_name text,
    display_place_name text,
    locality text,
    distance_m double precision
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        pn.place_name_id,
        pn.place_name,
        pn.display_place_name,
        pn.locality,
        ST_Distance(
            pn.geom::geography,
            ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
        ) AS distance_m
    FROM ccc.place_name AS pn
    WHERE ST_DWithin(
        pn.geom::geography,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
        radius_m
    )
    ORDER BY distance_m
    LIMIT result_limit;
$$;

-- Distance (metres) from a point to a specific place name
CREATE OR REPLACE FUNCTION ccc.distance_to_place_name_m(
    lon double precision,
    lat double precision,
    p_place_name_id integer
)
RETURNS double precision
LANGUAGE sql
STABLE
AS $$
    SELECT ST_Distance(
        pn.geom::geography,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
    )
    FROM ccc.place_name AS pn
    WHERE pn.place_name_id = p_place_name_id;
$$;

-- Place names in a locality (text filter; optional spatial bbox unused)
CREATE OR REPLACE FUNCTION ccc.place_names_by_locality(
    p_locality text,
    result_limit integer DEFAULT 100
)
RETURNS TABLE (
    place_name_id integer,
    place_name text,
    display_place_name text,
    locality text
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        pn.place_name_id,
        pn.place_name,
        pn.display_place_name,
        pn.locality
    FROM ccc.place_name AS pn
    WHERE pn.locality ILIKE p_locality
    ORDER BY pn.place_name
    LIMIT result_limit;
$$;

-- ---------------------------------------------------------------------------
-- Street addresses
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ccc.nearest_street_addresses(
    lon double precision,
    lat double precision,
    radius_m double precision DEFAULT 1000,
    result_limit integer DEFAULT 20
)
RETURNS TABLE (
    street_address_id integer,
    street_address text,
    locality_name text,
    post_code text,
    distance_m double precision
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        sa.street_address_id,
        sa.street_address,
        sa.locality_name,
        sa.post_code,
        ST_Distance(
            sa.geom::geography,
            ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
        ) AS distance_m
    FROM ccc.street_address AS sa
    WHERE ST_DWithin(
        sa.geom::geography,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
        radius_m
    )
    ORDER BY distance_m
    LIMIT result_limit;
$$;

-- ---------------------------------------------------------------------------
-- Rating units
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ccc.nearest_rating_units(
    lon double precision,
    lat double precision,
    radius_m double precision DEFAULT 1000,
    result_limit integer DEFAULT 20
)
RETURNS TABLE (
    rating_unit_id integer,
    street_address text,
    locality_name text,
    distance_m double precision
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        ru.rating_unit_id,
        ru.street_address,
        ru.locality_name,
        ST_Distance(
            ru.center_point::geography,
            ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
        ) AS distance_m
    FROM ccc.rating_unit AS ru
    WHERE ST_DWithin(
        ru.center_point::geography,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography,
        radius_m
    )
    ORDER BY distance_m
    LIMIT result_limit;
$$;

CREATE OR REPLACE FUNCTION ccc.rating_units_containing_point(
    lon double precision,
    lat double precision
)
RETURNS TABLE (
    rating_unit_id integer,
    street_address text,
    locality_name text
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        ru.rating_unit_id,
        ru.street_address,
        ru.locality_name
    FROM ccc.rating_unit AS ru
    WHERE ST_Contains(
        ru.geom,
        ST_SetSRID(ST_MakePoint(lon, lat), 4326)
    );
$$;
