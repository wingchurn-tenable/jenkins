"""Minimal FastAPI web service used by the Jenkins CI/CD deployment plan."""
import os

from fastapi import FastAPI

app = FastAPI(title="myapp", version=os.getenv("APP_VERSION", "0.1.0"))


@app.get("/")
def root():
    return {"message": "Hello from myapp"}


@app.get("/health")
def health():
    """Liveness probe used by Docker healthcheck and the Jenkins Verify stage."""
    return {"status": "ok"}
