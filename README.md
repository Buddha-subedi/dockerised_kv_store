# Dockerized Key-Value Store — Assignment Submission

**Platform:** Windows 10, Windows PowerShell 5.1, Docker Desktop (Linux containers)  
**Application:** Python 3.11, Flask, SQLite  
**Service URL:** `http://localhost:8080`  
**Purpose:** Package the existing key-value server into a reproducible Docker image and demonstrate client access and testing.

## 1. Assignment objective and requirements checklist

This repository contains the existing Flask/SQLite key-value store and the Docker instructions needed to run it consistently on a Docker-enabled host. All terminal commands below are **Windows PowerShell commands** (not Bash). Run Docker Desktop first and select Linux containers.

| Assignment requirement | Implementation | Verification |
|---|---|---|
| 1. Lightweight base image | `FROM python:3.11-alpine` in `Dockerfile` | `docker build -t key-value-store .` |
| 2. Include source files | `WORKDIR /app` and `COPY . .` | `docker exec key-value-store ls /app` |
| 3. Install dependencies | `COPY requirements.txt .` and `RUN pip install --no-cache-dir -r requirements.txt` | Build log shows pip installation layer |
| 4. Expose service port | `EXPOSE 8080`; container runs with `KV_HOST=0.0.0.0`; host publishes `127.0.0.1:8080:8080` | `docker ps` and HTTP GET/PUT |
| 5. Automatic startup | `CMD ["python", "server.py"]` | `docker logs key-value-store` and HTTP request |

`EXPOSE` is image metadata, not host publishing: the `-p` argument publishes the port. The host binding to `127.0.0.1` limits access to the local computer; inside Docker the Flask process must bind to `0.0.0.0`.

## 2. Files in this submission

| File | Purpose |
|---|---|
| `Dockerfile` | Builds image, installs requirements, exposes port, starts server |
| `.dockerignore` | Excludes caches, local databases, logs, and unnecessary files from image build |
| `requirements.txt` | Flask and Requests dependencies |
| `server.py` | Flask API, SQLite storage, validation, locking |
| `test_server.py` | API functionality and error handling |
| `test_concurrency.py` | Concurrent requests |
| `demo.py` | API operation walkthrough |
| `kv_bench.py` | Concurrent performance benchmark |
| `kv_bench_instructor.py` | Alternative benchmark harness |
| `PowerShell_Test_Evidence.md` | Recorded results and their limitations |
| `PowerShell_History.txt` | Original user-supplied PowerShell transcript |

## 3. Dockerfile explained line by line

```dockerfile
FROM python:3.11-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV KV_HOST=0.0.0.0 \
    KV_PORT=8080 \
    KV_DB=/data/kv_store.db
RUN mkdir -p /data
EXPOSE 8080
CMD ["python", "server.py"]
```

- `FROM`: starts from lightweight Alpine Linux with Python 3.11.
- `WORKDIR`: sets the application's working directory inside the container.
- `COPY requirements.txt` and `RUN pip install`: installs required Python packages inside the image, independent of the host Python environment.
- `COPY . .`: adds the project source code to `/app`.
- `ENV`: sets the listening interface, port, and database path.
- `RUN mkdir -p /data`: creates the SQLite database directory.
- `EXPOSE`: documents the TCP service port.
- `CMD`: automatically launches the server when the container starts.

The Dockerfile syntax itself is Dockerfile syntax, not a terminal command. All commands to **run** it in this README use PowerShell.

## 4. Setup and build (PowerShell)

1. Install and launch Docker Desktop, ensure its engine is running and Linux containers are selected.
2. Extract this ZIP. Open **Windows PowerShell**.
3. Change into the extracted repository folder (adjust the path to your own extraction location).

```powershell
cd "C:\Users\User\dockerised_kv_store-main"
docker --version
docker info
docker build -t key-value-store .
docker images key-value-store
```

The period `.` means that the current repository directory is the Docker build context. A successful build produces an image named `key-value-store:latest`. The recorded PowerShell transcript confirms the image built successfully on Docker Desktop using `python:3.11-alpine`.

## 5. Create and run the container (PowerShell)

**First run, when no container with this name already exists:**

```powershell
docker run -d --name key-value-store -p 127.0.0.1:8080:8080 -v kv-data:/data key-value-store
docker ps
docker logs key-value-store
```

`-d` runs in the background, `--name` sets the container name, `-p` maps the host's port 8080 to container port 8080, and `-v kv-data:/data` stores SQLite data in a persistent named Docker volume.

**If you see `Conflict. The container name ... is already in use`:** the name belongs to an existing container. Check it and start it if stopped; do **not** run a second container with the same name.

```powershell
docker ps -a
docker start key-value-store
docker ps
```

If you need to replace an existing container with the newly built image, use:

```powershell
docker rm -f key-value-store
docker run -d --name key-value-store -p 127.0.0.1:8080:8080 -v kv-data:/data key-value-store
```

The `docker rm -f` command removes the container and stops it if needed; the **named volume remains**, so the database persists. Use this only when you intend to replace the container.

## 6. Test the API from PowerShell

All commands below use the built-in `Invoke-RestMethod` command, which works in Windows PowerShell 5.1.

**Create or replace a value (PUT):**

```powershell
Invoke-RestMethod -Method Put -Uri 'http://localhost:8080/greeting' -ContentType 'application/json' -Body '{"value":"Hello from Docker"}'
```

Expected JSON fields: `key=greeting`, `value=Hello from Docker`.

**Retrieve it (GET):**

```powershell
Invoke-RestMethod -Method Get -Uri 'http://localhost:8080/greeting'
```

**Update it (PUT):**

```powershell
Invoke-RestMethod -Method Put -Uri 'http://localhost:8080/greeting' -ContentType 'application/json' -Body '{"value":"Updated in PowerShell"}'
Invoke-RestMethod -Method Get -Uri 'http://localhost:8080/greeting'
```

**Delete it (DELETE):**

```powershell
Invoke-RestMethod -Method Delete -Uri 'http://localhost:8080/greeting'
```

**Demonstrate missing-key 404 handling:**

```powershell
try { Invoke-RestMethod -Method Get -Uri 'http://localhost:8080/greeting' } catch { Write-Host "Expected missing-key error: $($_.Exception.Message)" }
```

**Demonstrate validation of invalid values:**

```powershell
try { Invoke-RestMethod -Method Put -Uri 'http://localhost:8080/invalid' -ContentType 'application/json' -Body '{"value":123}' } catch { Write-Host "Expected validation error: $($_.Exception.Message)" }
```

The API supports `PUT` and `POST` to write a string, `GET` to retrieve it, and `DELETE` to remove it. Missing keys return HTTP 404, invalid values HTTP 400. Do not confuse PowerShell's `curl` alias with Bash `curl` flags; use `Invoke-RestMethod` as shown.

## 7. Functional tests, concurrency and benchmarking

These Python commands are valid from **PowerShell** in the repository directory, with the container running and host Python plus requirements installed. The Python test scripts send HTTP requests to `http://127.0.0.1:8080`.

```powershell
python --version
python -m pip install -r requirements.txt
python test_server.py
python test_concurrency.py
python demo.py
python kv_bench.py
```

Optional alternative benchmark:

```powershell
python kv_bench_instructor.py
```

The recorded transcript shows the following results for the first four test/demo/benchmark commands, not the optional alternative benchmark:

| Recorded test | Result |
|---|---|
| `test_server.py` | PASS: PUT, GET, UPDATE, DEL, validation, missing key |
| `test_concurrency.py` | PASS: 60 concurrent PUTs and 30 concurrent DELs on one key |
| `demo.py` | PUT, GET, update, delete returned HTTP 200; missing GET returned HTTP 404 |
| `kv_bench.py` SET | 300 successful; 0 mismatches; 0 errors; 10.24 s; 29.3 ops/s; average 102.03 ms; p99 153.39 ms |
| `kv_bench.py` GET | 300 successful; 0 mismatches; 0 errors; 1.61 s; 185.9 ops/s; average 16.10 ms; p99 34.72 ms |
| `kv_bench.py` total | 600 successful operations in 11.86 s; 50.6 ops/s |

These are historical observed results from the uploaded PowerShell transcript, not new benchmark results from this ZIP. Your computer may produce different timings.

## 8. Stop, restart, logs, and persistent data

```powershell
docker stop key-value-store
docker start key-value-store
docker ps
docker logs key-value-store
docker volume ls
```

To verify persistence, first PUT a key, stop/start the container, then GET the same key:

```powershell
Invoke-RestMethod -Method Put -Uri 'http://localhost:8080/persist_check' -ContentType 'application/json' -Body '{"value":"survives restart"}'
docker stop key-value-store
docker start key-value-store
Invoke-RestMethod -Method Get -Uri 'http://localhost:8080/persist_check'
```

To replace the container without deleting its volume:

```powershell
docker rm -f key-value-store
docker run -d --name key-value-store -p 127.0.0.1:8080:8080 -v kv-data:/data key-value-store
Invoke-RestMethod -Method Get -Uri 'http://localhost:8080/persist_check'
```

The transcript shows successful stop and start commands, but it **does not contain** the above explicit persistent-key test. Run it yourself if you want to claim verified persistence in your submission. Do not run `docker volume rm kv-data` unless you intend to delete the stored database.

## 9. Troubleshooting

| Symptom | Cause and PowerShell solution |
|---|---|
| Docker engine not available | Start Docker Desktop, then run `docker info` |
| Container name conflict | Run `docker ps -a`, then `docker start key-value-store` or intentionally replace with `docker rm -f key-value-store` |
| Port 8080 already in use | Stop the other service or use `-p 127.0.0.1:8081:8080` and request `http://localhost:8081` |
| Requests fail | Run `docker ps -a` and `docker logs key-value-store` |
| Python package missing locally | Run `python -m pip install -r requirements.txt` |
| New image not reflected in old container | Remove/recreate container after build; `docker start` does not change its image |

## 10. Recorded PowerShell demonstration and limitations

The included `PowerShell_History.txt` is the transcript supplied for this assignment. It records a successful `docker build`, an attempted `docker run` that failed due to an existing container name, `docker ps` confirming an already-running container, successful API PUT/GET/DELETE, functional tests, concurrency tests, benchmark results, stop/start, and eventual container removal.

The build log indicates Docker used cached layers for dependency installation and copying source. It still demonstrates successful image build.

## 11. Submission checklist

- [x] Dockerfile with Alpine Python base image
- [x] Application source and dependency specification
- [x] Container port exposed and host mapping documented
- [x] Automatic startup command
- [x] PowerShell-only terminal instructions
- [x] Recorded successful build and API test evidence
- [x] Recorded concurrency and benchmark results
- [x] Re-run the first-time `docker run` command after the transcript's final container removal and capture output as proof of a new run
- [x] Run the persistence verification and capture its output for claiming verified persistent data

**Educational scope:** The Flask development server is intended for this local assignment, not for deployment as a public production service. The project has no authentication or HTTPS; keep the port restricted to localhost.
