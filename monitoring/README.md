## Monitoring stack overview

End‑to‑end observability using Prometheus (metrics), Grafana (dashboards), Loki+Promtail (logs), Tempo (traces), Pyroscope (profiles), and OpenTelemetry Collector (OTel gateway).

- Backend exports OTLP traces/metrics → `otel-collector`
- `otel-collector` exposes metrics for Prometheus and forwards traces to Tempo
- Promtail scrapes Docker container logs → Loki
- Grafana is pre‑provisioned with datasources and dashboards

Useful URLs:

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Loki API: `http://localhost:3100`
- Tempo API: `http://localhost:3200`
- Pyroscope: `http://localhost:4040`

Start only monitoring services:

```bash
./scripts/build.sh monitoring
# or
docker compose up -d prometheus grafana loki promtail tempo pyroscope otel-collector postgres-exporter
```

All container and port mappings are defined in `docker-compose.yml`.

## Data flow

- Backend → OTLP (HTTP/GRPC) → `otel-collector` (`4318`/`4317`)
- `otel-collector` metrics → Prometheus scrape (`8889`)
- `otel-collector` traces → Tempo (`4318`)
- Docker container logs → Promtail → Loki (`3100`)
- Grafana queries Prometheus, Loki, Tempo, Pyroscope and renders dashboards

## Components

### OpenTelemetry Collector (`otel-collector`)

- Purpose: central receive/process/export for telemetry
- Ports: `8889` (Prometheus scrape), `8888` (self metrics)
- Receivers: OTLP HTTP/GRPC at `0.0.0.0:4318/4317`
- Pipelines: traces → Tempo, metrics → Prometheus
- Config: `monitoring/otelcol/config.yaml`

```yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
processors:
  batch: {}
exporters:
  otlphttp/tempo: { endpoint: http://tempo:4318 }
  prometheus: { endpoint: 0.0.0.0:8889 }
service:
  pipelines:
    traces:   { receivers: [otlp], processors: [batch], exporters: [otlphttp/tempo] }
    metrics:  { receivers: [otlp], processors: [batch], exporters: [prometheus] }
```

Backend is configured with OTel env vars in `docker-compose.yml` to send to `otel-collector`:

```env
OTEL_SERVICE_NAME=nestjs-backend
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http
```

### Prometheus

- Purpose: scrape and store metrics
- Port: `9090`
- Scrape targets (see `monitoring/simple-prometheus.yml`):
  - `otel-collector:8889` (OTel pipeline metrics)
  - `postgres-exporter:9187` (Postgres metrics)
  - Itself at `localhost:9090`

### Grafana

- Purpose: visualization and cross‑navigation
- Port: `3001` (maps to container `3000`)
- Provisioning:
  - Datasources: `monitoring/grafana/provisioning/datasources/datasources.yml`
    - Prometheus → `http://prometheus:9090` (default)
    - Loki → `http://loki:3100`
    - Tempo → `http://tempo:3200` (traces to logs/metrics enabled)
    - Pyroscope → `http://pyroscope:4040`
  - Dashboards directory: `monitoring/grafana/dashboards`
- Login: default admin password is set to `admin` in compose env

Included dashboards:

- `simple-dashboard.json` — example application SLI/SLO style panels
- `postgres-9628.json` — community PostgreSQL dashboard (ID 9628) wired to Prometheus

### Loki (logs)

- Purpose: log storage and querying
- Port: `3100`
- Config: `monitoring/loki/config.yaml`
  - Storage: `boltdb-shipper` with filesystem chunks
  - Retention: `168h` (7 days)
  - Structured metadata enabled

### Promtail (log shipper)

- Purpose: scrape Docker container logs and push to Loki
- Config: `monitoring/promtail/config.yml`
  - Docker service discovery on `/var/run/docker.sock`
  - Applies labels: `job=docker`, `container`, `service`, `service_name`, `compose_project`, `stream`
  - Pipeline stage `docker` to parse JSON docker logs

Example LogQL queries in Grafana Explore:

```logql
{service="backend"} |~ "ERROR|WARN"
{compose_project="react-nestjs-postgres-usermanagement-crud"} |= "nestjs"
```

### Tempo (traces)

- Purpose: distributed tracing backend
- Ports: OTLP `4318/4317`, query `3200`
- Config: `monitoring/tempo/tempo.yaml`
  - Local storage under `/tmp/tempo`
  - Metrics generator enabled for `service_graphs` and `span_metrics`

In Grafana, use Explore → Traces (Tempo) and correlate with logs/metrics via the built‑in links.

### Pyroscope (profiles)

- Purpose: continuous profiling backend
- Port: `4040`
- Datasource is pre‑provisioned in Grafana. If the application integrates `@pyroscope/nodejs`, profiles will appear under the `nestjs-backend` service.

### Postgres Exporter

- Purpose: export PostgreSQL metrics to Prometheus
- Image: `prometheuscommunity/postgres-exporter:v0.15.0`
- Port (scrape): `9187`
- Env in compose points to `postgres` service and includes extended queries file
- Custom queries: `monitoring/postgres/queries.yaml`, including:
  - `pg_locks_by_mode` (gauge by lock mode)
  - `pg_deadlocks_total` (counter per database)
  - `pg_stat_statements_timing` (execution time and calls by role/db)

In Prometheus targets, you should see `postgres-exporter` healthy. Grafana includes dashboard ID 9628; select datasource `Prometheus` and instance `postgres-exporter:9187` if not auto‑detected.

## How to verify

- Prometheus targets:

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].labels'
```

- OTel Collector metrics endpoint:

```bash
curl -s http://localhost:8889/metrics | head -n 20
```

- Loki labels for a container:

```bash
curl -G 'http://localhost:3100/loki/api/v1/labels' --data-urlencode 'start=0'
```

## Troubleshooting

- No metrics in Grafana:
  - Check Prometheus targets (`otelcol-metrics`, `postgres-exporter`) are UP
  - Ensure backend is sending OTLP to `otel-collector:4318`
- No logs in Loki:
  - Ensure `promtail` can read `/var/run/docker.sock` and depends on `loki`
  - Use label `service`/`service_name` to filter in Explore
- No traces in Tempo:
  - Verify backend OTel SDK is enabled and service name is set (`nestjs-backend`)
  - Check `otel-collector` logs for export errors

## File map

- `docker-compose.yml` — service definitions and ports
- `monitoring/simple-prometheus.yml` — Prometheus scrape config
- `monitoring/grafana/provisioning/*` — datasources and dashboards provisioning
- `monitoring/loki/config.yaml` — Loki storage/retention
- `monitoring/promtail/config.yml` — Docker log scraping
- `monitoring/tempo/tempo.yaml` — Tempo config
- `monitoring/otelcol/config.yaml` — OTel Collector pipelines
- `monitoring/postgres/queries.yaml` — Extended Postgres metrics


