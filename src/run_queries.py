"""Run the analytical SQL files (read-only) in order and save each result to results/<file>.csv."""
import csv
import sys
from pathlib import Path

import psycopg2

sys.path.insert(0, str(Path(__file__).resolve().parent))
from load_data import ROOT, URI  # noqa: E402  (reads DATABASE_URI from .env)

SKIP = {"00_schema.sql", "01_load.sql"}  # schema/load are run by load_data.py


def main() -> None:
    files = sorted(p for p in (ROOT / "sql").glob("*.sql") if p.name not in SKIP)
    (ROOT / "results").mkdir(exist_ok=True)
    with psycopg2.connect(URI) as conn, conn.cursor() as cur:
        conn.set_session(readonly=True)
        for path in files:
            cur.execute(path.read_text(encoding="utf-8"))
            rows, cols = cur.fetchall(), [d[0] for d in cur.description]
            with open(ROOT / "results" / f"{path.stem}.csv", "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(cols)
                writer.writerows(rows)
            print(f"{path.name}: {len(rows)} rows -> results/{path.stem}.csv")


if __name__ == "__main__":
    main()
