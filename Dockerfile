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
