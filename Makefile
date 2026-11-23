# Usage: make up | load | queries | analysis   (needs: make, Python venv in .venv, .env with DATABASE_URI)
PY = .venv/Scripts/python

.PHONY: up load queries analysis

up:            # optional Postgres in Docker (host port 5433)
	docker compose up -d

load:          # create schema and load data/raw/email_hillstrom.csv
	$(PY) src/load_data.py

queries:       # run sql/02..10 and the extra queries, save results/*.csv
	$(PY) src/run_queries.py

analysis:      # Python tests and statistics (added in steps 5-6)
	$(PY) -m pytest tests
