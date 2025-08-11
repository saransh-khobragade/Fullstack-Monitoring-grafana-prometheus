# React + NestJS + Postgres (CRUD) with Full Observability

Full‑stack user management app with React (frontend), NestJS (backend), Postgres, and an observability stack: Prometheus, Grafana, Loki, Promtail, Tempo, Pyroscope, and OpenTelemetry Collector.

## 🚀 Quick start (Docker)

```bash
# Build and start selected services (or use "all")
./scripts/build.sh all

# Or only app core
./scripts/build.sh frontend backend postgres pgadmin

# Or only monitoring
./scripts/build.sh monitoring
```

Services:

- Frontend: http://localhost:3000
- Backend API: http://localhost:8080
- Swagger: http://localhost:8080/api
- pgAdmin: http://localhost:5050 (admin@admin.com / admin)
- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090
- Pyroscope: http://localhost:4040

## ♻️ Rebuild workflow

Use a single script with two modes:

```bash
# For config/env updates → SOFT (no image build)
./scripts/rebuild.sh <service|all> soft

# For code/Dockerfile changes → HARD (rebuild image)
./scripts/rebuild.sh <service|all> hard
```

Examples:

```bash
# Pick up Prometheus config changes
./scripts/rebuild.sh prometheus soft

# After backend code edits
./scripts/rebuild.sh backend hard

# Bring Postgres exporter online
./scripts/rebuild.sh postgres-exporter soft
```

Supported services: `frontend backend postgres pgadmin prometheus grafana loki promtail tempo pyroscope otel-collector postgres-exporter` (or `all`).

## 📊 Observability (OTel‑first)

- Traces and metrics are emitted via OpenTelemetry SDK → `otel-collector`
- Collector routes: traces → Tempo, metrics → Prometheus. Logs via Promtail → Loki
- Profiling via `@pyroscope/nodejs`

Grafana is pre‑provisioned with datasources and a PostgreSQL dashboard.

### Observability architecture

```text
Client
  |
  v
Frontend (http 3000)
  |
  | HTTP
  v
Backend (http 8080)
  |\
  | \__ DB conn
  |     v
  |   Postgres (5432)
  |       ^
  |       |
  |     pgAdmin (http 5050)
  |
  | OTLP 4318/4317
  v
OTel Collector
  |  \
  |   \__ Metrics endpoint /metrics (8889)  --> scraped by Prometheus (9090)
  |                                          \
  |                                           \__ Grafana (http 3001) queries Prometheus
  |
  \__ Traces --> Tempo (3200)  --> Grafana (Traces Explore)

Docker container logs --> Promtail --> Loki (3100) --> Grafana (Logs Explore)

Profiles (from Backend) --> Pyroscope (4040) --> Grafana (Profiles)

Prometheus also scrapes Postgres Exporter (9187) --> Postgres
```

### PostgreSQL monitoring

- Postgres Exporter is enabled as `postgres-exporter`
- Prometheus scrapes it at `postgres-exporter:9187`
- Grafana dashboard (ID 9628) is provisioned as “PostgreSQL Database”

In the dashboard, defaults are set, but if needed:
- Datasource: `Prometheus`
- Instance: `postgres-exporter:9187`
- Database: `test_db`

## 🧑‍💻 Local frontend dev

```bash
cd frontend
yarn install
yarn dev   # http://localhost:5173
```

## 🔧 Useful commands

```bash
# Tail service logs
docker compose logs -f backend

# Run simple API smoke tests
./scripts/test-api.sh.sh

# Prometheus targets (should include postgres-exporter and otelcol-metrics)
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].labels'
```