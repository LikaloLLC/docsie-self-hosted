FROM python:3.11-slim-bookworm
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
LABEL org.opencontainers.image.title="Docsie OCR pipeline runtime"
# The chart mounts its server at /app/config/server.py.
CMD ["python", "/app/config/server.py"]
