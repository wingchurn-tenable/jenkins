#!/usr/bin/env bash
# Pull an image and (re)start the app container on the target host.
# Usage: ./deploy.sh <full-image-ref>
# Called by the Jenkins Deploy stage, or run manually for a rollback.
set -euo pipefail

IMAGE="${1:?Usage: deploy.sh <image-ref>}"
NAME="myapp"
ENV_FILE="/opt/myapp/.env"

docker pull "$IMAGE"
docker rm -f "$NAME" 2>/dev/null || true
docker run -d --name "$NAME" --restart unless-stopped \
  -p 8000:8000 --env-file "$ENV_FILE" "$IMAGE"

echo "Started $NAME from $IMAGE"
