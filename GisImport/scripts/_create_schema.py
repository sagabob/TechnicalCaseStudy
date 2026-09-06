from src.db import apply_schema, connect

with connect() as conn:
    apply_schema(conn)
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT table_schema || '.' || table_name
            FROM information_schema.tables
            WHERE table_schema = 'ccc'
            ORDER BY 1
            """
        )
        print("tables:", cur.fetchall())
print("schema ok")
