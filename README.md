# myapp — Jenkins CI/CD Deployment Bundle

A complete, ready-to-run set of files for shipping a Dockerized Python (FastAPI) web API
through a Jenkins pipeline. Pairs with `jenkins-deployment-plan.md` and
`jenkins-on-ec2-setup.md`.

## File map

```
jenkins-deployment/
├── app/
│   ├── __init__.py
│   └── main.py              # FastAPI app with / and /health
├── tests/
│   └── test_main.py         # pytest suite
├── requirements.txt         # runtime deps (pinned)
├── requirements-dev.txt     # test + lint tooling
├── pyproject.toml           # ruff + pytest config
├── Dockerfile               # multi-stage, non-root, port 8000
├── docker-compose.yml       # local run / simple single-host deploy
├── .dockerignore
├── .gitignore
├── .env.example             # copy to .env on the target host
├── Jenkinsfile              # the CI/CD pipeline (lives in repo root)
└── infra/
    ├── deploy.sh            # pull + (re)start container on target host
    ├── nginx/
    │   ├── jenkins.conf         # reverse proxy for the Jenkins UI
    │   └── upgrade-map.conf     # websocket $connection_upgrade map
    └── systemd/
        ├── java.conf            # pin Jenkins to Java 21
        └── proxy.conf           # bind Jenkins to localhost
```

## Run locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
ruff check app/
pytest
uvicorn app.main:app --reload      # http://localhost:8000/health
```

## Run with Docker

```bash
cp .env.example .env
docker compose up --build
curl localhost:8000/health
```

## Wire into Jenkins

1. Push this directory to your Git remote (Jenkinsfile must be at the repo root).
2. In Jenkins add three credentials: `registry-creds`, `deploy-ssh-key`, `app-env`.
3. Edit the `environment{}` block in the `Jenkinsfile` — set `REGISTRY` and `DEPLOY_HOST`.
4. Create a Multibranch Pipeline pointing at the repo; it auto-discovers the Jenkinsfile.
5. On the target host: install Docker, create the `deploy` user, and place real secrets
   at `/opt/myapp/.env` (root-owned, `chmod 600`).

## Jenkins host (EC2) infra files

- `infra/systemd/java.conf` → `/etc/systemd/system/jenkins.service.d/java.conf` (Java 21 fix).
- `infra/systemd/proxy.conf` → same dir, to bind Jenkins to localhost behind nginx.
- `infra/nginx/*.conf` → `/etc/nginx/conf.d/`, then run `certbot --nginx -d <domain>` for TLS.

After any systemd drop-in change: `sudo systemctl daemon-reload && sudo systemctl restart jenkins`.

## Customize for Flask/Django

Swap the Dockerfile `CMD` to gunicorn (commented in the Dockerfile), replace FastAPI deps
in `requirements.txt`, and keep a `/health` route returning 200.
