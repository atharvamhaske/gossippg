.PHONY: help test run migrate seed notify sql-all docker-up docker-down docker-logs

# Optionally load local env vars (do NOT commit real secrets).
# Create `.env` (based on `env.example`) and it will be loaded automatically.
# Format:
#   DATABASE_URL=postgres://...
#   PG_CHANNEL=events
-include .env
-include env.local
export

DATABASE_URL ?=
PG_CHANNEL ?= events

DATABASE_URL_CLEAN = $(strip $(subst ",,$(DATABASE_URL)))
PG_CHANNEL_CLEAN = $(strip $(subst ",,$(PG_CHANNEL)))

help:
	@echo "Targets:"
	@echo "  make test       - go test ./..."
	@echo "  make run        - run the listener (requires DATABASE_URL)"
	@echo "  make migrate    - apply SQL migrations (requires DATABASE_URL)"
	@echo "  make seed       - insert seed rows (requires DATABASE_URL)"
	@echo "  make notify     - send a manual NOTIFY (requires DATABASE_URL)"
	@echo "  make sql-all    - migrate + seed + notify (requires DATABASE_URL)"
	@echo "  make docker-up  - start local Postgres via docker compose"
	@echo "  make docker-down- stop local Postgres"
	@echo "  make docker-logs- tail local Postgres logs"
	@echo ""
	@echo "Env:"
	@echo "  DATABASE_URL    - postgres connection string (required for run/migrate/seed/notify)"
	@echo "  PG_CHANNEL      - listen channel (default: events)"

test:
	go test ./...

run:
	@if [ -z "$(DATABASE_URL_CLEAN)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	DATABASE_URL="$(DATABASE_URL_CLEAN)" PG_CHANNEL="$(PG_CHANNEL_CLEAN)" go run ./cmd

migrate:
	@if [ -z "$(DATABASE_URL_CLEAN)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	psql "$(DATABASE_URL_CLEAN)" -f sql/migrations/001_init.sql

seed:
	@if [ -z "$(DATABASE_URL_CLEAN)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	psql "$(DATABASE_URL_CLEAN)" -f sql/test/001_seed.sql

notify:
	@if [ -z "$(DATABASE_URL_CLEAN)" ]; then echo "DATABASE_URL is required"; exit 1; fi
	psql "$(DATABASE_URL_CLEAN)" -f sql/test/002_notify_manual.sql

sql-all: migrate seed notify

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-logs:
	docker compose logs -f db


