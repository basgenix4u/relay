FROM python:3.13-slim
WORKDIR /app
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt \
    && useradd --create-home --uid 10001 relay \
    && mkdir -p /data && chown relay:relay /data
COPY backend/ /app/backend/
COPY web_release/ /app/web_release/
ENV RELAY_DATA_DIR=/data PORT=8000 PYTHONUNBUFFERED=1
USER relay
EXPOSE 8000
VOLUME ["/data"]
CMD ["python", "-m", "uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
