# ---------------------------------------------------------------------------
# Dockerfile – Library Management System
# Multi-purpose Python 3.12 image running the Flask application via Gunicorn.
# ---------------------------------------------------------------------------

# --- Base image ---
FROM python:3.12-slim

# Metadata
LABEL maintainer="student" \
      description="Library Management System - DevOps CI/CD Demo"

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# --- Working directory ---
WORKDIR /app

# --- Install dependencies first (layer caching) ---
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --- Copy application code ---
COPY . .

# --- Create directory for the persistent SQLite database ---
RUN mkdir -p /data

# Point the app at the persistent volume path
ENV DATABASE_PATH=/data/library.db

# --- Expose the application port ---
EXPOSE 5000

# --- Health check (used by Docker & Compose) ---
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# --- Run the application ---
CMD ["python", "app.py"]
