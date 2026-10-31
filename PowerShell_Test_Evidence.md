# PowerShell test evidence

Source: user-supplied `PowerShell_History.txt` (October 31, 2026, Windows PowerShell 5.1). This is a summary of recorded results, not a newly executed test.

- Docker image build: `docker build -t key-value-store .` finished successfully using `python:3.11-alpine`.
- Docker run attempt: name conflict because `key-value-store` was already running; `docker ps` confirmed the existing container on `127.0.0.1:8080->8080/tcp`.
- PowerShell `Invoke-RestMethod`: PUT, GET, DELETE of `greeting` succeeded.
- `python test_server.py`: PASS for PUT, GET, UPDATE, DEL, validation, missing-key handling.
- `python test_concurrency.py`: PASS for 60 concurrent PUTs and 30 concurrent DELs on one key.
- `python demo.py`: successful create/read/update/delete and expected missing-key 404.
- `python kv_bench.py`: SET 300/300, 29.3 ops/s, average 102.03 ms, p99 153.39 ms; GET 300/300, 185.9 ops/s, average 16.10 ms, p99 34.72 ms; total 600 successful operations in 11.86 s.
- `docker stop` and `docker start`: succeeded; `docker ps` confirmed running afterward.
- Final `docker rm -f key-value-store`: succeeded.

**Not established by the transcript:** successful fresh `docker run` during the recorded session, a persistence GET after restarting/recreating the container, or an instructor-benchmark execution. README includes reproducible PowerShell commands for those checks.
