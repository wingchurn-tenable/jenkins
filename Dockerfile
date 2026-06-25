# ---- Stage 1: build dependencies ----
FROM python:3.12-slim AS builder
WORKDIR /app
ENV PIP_NO_CACHE_DIR=1 PYTHONDONTWRITEBYTECODE=1
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# ---- Stage 2: runtime ----
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PORT=8000

# create unprivileged user
RUN useradd --create-home --uid 10001 appuser

COPY --from=builder /install /usr/local
COPY app/ ./app/

USER appuser
EXPOSE 8000

# FastAPI/ASGI. For Flask/Django (WSGI) use:
#   CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8000", "app.main:app"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
