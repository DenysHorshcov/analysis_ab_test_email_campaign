"""Create schema and load data/raw/email_hillstrom.csv into PostgreSQL."""
import os
from pathlib import Path

import psycopg2

ROOT = Path(__file__).resolve().parents[1]


def _load_env() -> None:
    """Read KEY=VALUE lines from .env (not committed) into os.environ."""
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


_load_env()
URI = os.environ["DATABASE_URI"]  # e.g. postgresql://user:password@localhost:5432/abtest (set in .env)
CSV = ROOT / "data" / "raw" / "email_hillstrom.csv"

STAGING = """
DROP TABLE IF EXISTS stg_hillstrom;
CREATE TABLE stg_hillstrom (
    customer_id SERIAL,
    recency SMALLINT, history_segment TEXT, history NUMERIC(10,2),
    mens SMALLINT, womens SMALLINT, zip_code TEXT, newbie SMALLINT,
    channel TEXT, segment TEXT, visit SMALLINT, conversion SMALLINT, spend NUMERIC(10,2)
);
"""
COPY = """COPY stg_hillstrom (recency, history_segment, history, mens, womens, zip_code,
newbie, channel, segment, visit, conversion, spend) FROM STDIN WITH (FORMAT csv, HEADER true)"""


def main() -> None:
    with psycopg2.connect(URI) as conn, conn.cursor() as cur:
        cur.execute((ROOT / "sql" / "00_schema.sql").read_text(encoding="utf-8"))
        cur.execute(STAGING)
        with open(CSV, encoding="utf-8") as f:
            cur.copy_expert(COPY, f)
        cur.execute((ROOT / "sql" / "01_load.sql").read_text(encoding="utf-8"))
        for t in ("customers", "assignments", "outcomes"):
            cur.execute(f"SELECT COUNT(*) FROM {t}")
            print(t, cur.fetchone()[0])


if __name__ == "__main__":
    main()
