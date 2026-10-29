# Key–Value Store API

**A lightweight, containerized HTTP key–value service built with Python, Flask, and SQLite.**

[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.x-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![SQLite](https://img.shields.io/badge/SQLite-Persistent-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org/)

A compact REST-style service for storing, retrieving, updating, and deleting string values by key. It demonstrates HTTP API design, transactional persistence, thread-safe write operations, container deployment, and reproducible load testing without requiring a separate database server.

> **Scope:** Designed as a single-process educational/reference service for local development and trusted environments—not a production-ready, internet-facing database. It has no authentication, TLS, rate limiting, or multi-instance coordination.

## Highlights

- **Simple JSON API:** `PUT`, `GET`, and `DELETE`, plus `POST` as a write alias.
- **Durable storage:** SQLite-backed records survive server restarts; Docker volumes preserve data across container replacement.
- **Concurrent requests:** Flask's threaded server, per-request database connections, and a process-local lock around writes/deletes.
- **Predictable errors:** JSON responses with meaningful HTTP status codes.
- **Container-first setup:** Small Python Alpine base image, configurable host/port, and one-command startup.
- **Reproducible checks:** Functional tests, concurrency tests, demonstrations, and latency/throughput benchmarking scripts.

## Architecture

```text
Client / test script
       |
       | HTTP (port 8080)
       v
+------------------------------+
| Flask API (server.py)        |
|  PUT/POST  GET  DELETE       |
|  request validation          |
|  thread lock for mutations   |
+---------------+--------------+
                |
                | SQLite transactions
                v
       /data/kv_store.db
       (Docker named volume)
```

Each request opens and closes its own SQLite connection. Modifying operations use a process-local `threading.Lock` and parameterized SQL statements. SQLite transactions commit successful operations and roll back failures. The locking strategy applies **within one server process**, not across multiple replicas.

## Quick start with Docker

**Prerequisite:** Docker Engine or Docker Desktop running.

```bash
# From the repository root
docker build -t key-value-store .

docker run -d \
  --name key-value-store \
  -p 127.0.0.1:8080:8080 \
  -v kv-data:/data \
  key-value-store

# Inspect status and logs
docker ps
docker logs key-value-store
```

The API is available at **http://localhost:8080**. The example publishes the port only to the host's loopback interface. Docker uses `KV_HOST=0.0.0.0` *inside* the container to accept forwarded requests.

For **Windows PowerShell**, use this single-line equivalent:

```powershell
docker build -t key-value-store .
docker run -d --name key-value-store -p 127.0.0.1:8080:8080 -v kv-data:/data key-value-store
```

> `EXPOSE 8080` documents the listening port; the `-p` option actually publishes it to your computer.

## API reference

The endpoint is `/<key>`, where `<key>` is a single URL path segment. All stored values must be strings.

| Method | Endpoint | Purpose | Success | Common errors |
| --- | --- | --- | --- | --- |
| `PUT` | `/{key}` | Create or replace | `200` | `400`, `500` |
| `POST` | `/{key}` | Write alias | `200` | `400`, `500` |
| `GET` | `/{key}` | Read a value | `200` | `404`, `500` |
| `DELETE` | `/{key}` | Remove a value | `200` | `404`, `500` |

### Write a key

```bash
curl -X PUT http://localhost:8080/greeting \
  -H 'Content-Type: application/json' \
  -d '{"value":"Hello from Docker"}'
```

```json
{"key":"greeting","value":"Hello from Docker"}
```

Sending another `PUT` to the same key replaces its value. `POST` accepts the same JSON body as an alternative write method.

### Read a key

```bash
curl http://localhost:8080/greeting
```

```json
{"key":"greeting","value":"Hello from Docker"}
```

### Delete a key

```bash
curl -X DELETE http://localhost:8080/greeting
```

```json
{"key":"greeting","message":"Deleted"}
```

### Validation and missing keys

An invalid write such as `{"value":123}` returns `400`:

```json
{"error":"Expected JSON object with string field 'value'"}
```

A `GET` or `DELETE` for a missing key returns `404`:

```json
{"error":"Key not found"}
```

### PowerShell examples

```powershell
Invoke-RestMethod -Method Put -Uri 'http://localhost:8080/greeting' -ContentType 'application/json' -Body '{"value":"Hello from Docker"}'
Invoke-RestMethod -Method Get -Uri 'http://localhost:8080/greeting'
Invoke-RestMethod -Method Delete -Uri 'http://localhost:8080/greeting'
```

## Run locally without Docker

Requires Python 3.11+ (Python 3.10 may also work).

```bash
python -m venv .venv
# macOS/Linux: source .venv/bin/activate
# Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
python server.py
```

By default, the server binds to `127.0.0.1:8080` and creates `kv_store.db` in the current directory. Run client commands from another terminal. To avoid port conflicts, stop the local server before starting the Docker container on the same port.

## Configuration

| Variable | Local default | Container value | Description |
| --- | --- | --- | --- |
| `KV_HOST` | `127.0.0.1` | `0.0.0.0` | Interface to bind |
| `KV_PORT` | `8080` | `8080` | Listening port |
| `KV_DB` | `kv_store.db` | `/data/kv_store.db` | SQLite database file |

Set these environment variables when starting the service. Example: `docker run -e KV_PORT=9090 -p 127.0.0.1:9090:9090 ...` (include the image and volume options as in the quick start).

## Testing and benchmarking

Install dependencies locally with `pip install -r requirements.txt`, start the server, and then run:

```bash
python test_server.py       # API operations, updates, validation, 404 responses
python test_concurrency.py  # Concurrent writes and deletes
python demo.py              # Interactive request demonstration
python kv_bench.py          # Multi-threaded PUT/GET benchmark
```

`kv_bench.py` defaults to **3 client threads** and **100 operations per thread**. It reports timing and request outcomes. The repository also includes `kv_bench_instructor.py` as an alternative benchmark harness.

These scripts target `http://127.0.0.1:8080`, so they work against either a locally running server or the published Docker container. Run tests against an isolated database if you need to preserve existing keys.

> Benchmark performance varies by hardware, filesystem, OS, and container settings. Run the scripts on your own system for representative results; no throughput or latency guarantee is implied.

## Data persistence and container lifecycle

The named volume `kv-data` stores the SQLite file outside the container's writable layer. To restart or recreate the service:

```bash
docker stop key-value-store
docker start key-value-store

# Or recreate while keeping the same volume:
docker rm -f key-value-store
docker run -d --name key-value-store -p 127.0.0.1:8080:8080 -v kv-data:/data key-value-store
```

Stored keys remain available when the same volume is reused. **Deleting the `kv-data` volume removes the persisted database.**

## Repository layout

```text
.
├── Dockerfile                 # Container build and startup
├── .dockerignore              # Files excluded from image build context
├── .gitignore                 # Local artifacts excluded from Git
├── README.md                  # Project documentation
├── requirements.txt           # Python dependencies
├── server.py                  # Flask API, SQLite storage, concurrency
├── test_server.py             # Functional API checks
├── test_concurrency.py        # Concurrent request checks
├── demo.py                    # API demonstration
├── kv_bench.py                # PUT/GET load benchmark
└── kv_bench_instructor.py     # Additional benchmark harness
```

Database files, logs, virtual environments, and Python caches are intentionally excluded from version control and the Docker build context.

## Design considerations and limitations

- **Single-process concurrency:** A Python lock serializes writes and deletes in one process; it is not a distributed lock.
- **SQLite:** A good fit for a lightweight local service, but not intended here for high-scale, multi-replica deployment.
- **HTTP server:** Flask's built-in development server is used for simplicity; use a production WSGI server and appropriate security controls for real deployments.
- **Security:** No authentication, authorization, encryption in transit, rate limiting, or request-size policy is implemented. Do not expose this service directly to the public internet.
- **Data model:** Keys are URL path segments and values are JSON strings; there is no expiration, namespace, listing, or multi-key transaction API.

## Technology stack

- **Python 3.11** — application runtime
- **Flask 3.x** — HTTP routing and JSON responses
- **SQLite** — transactional, file-backed storage
- **Docker** — reproducible packaging and deployment
- **Requests** — client tests and benchmark requests

## Future improvements

Potential extensions include authentication, health/readiness endpoints, structured JSON logging, CI test automation, database migration tooling, metrics, and deployment behind a production WSGI server.
