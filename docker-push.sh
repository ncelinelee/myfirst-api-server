#!/usr/bin/env bash
set -euo pipefail
: "${STUDENT_NUM:?STUDENT_NUM is required}"
: "${CLASS_NAME:?CLASS_NAME is required}"
: "${DOCKER_REGISTRY:?DOCKER_REGISTRY is required}"
: "${DOCKER_REGISTRY_USER:?DOCKER_REGISTRY_USER is required}"
: "${DOCKER_REGISTRY_PASSWORD:?DOCKER_REGISTRY_PASSWORD is required}"
LOCAL_IMAGE="${STUDENT_NUM}-webserver:1.0"
REMOTE_IMAGE="${DOCKER_REGISTRY}/${CLASS_NAME}/${LOCAL_IMAGE}"
printf '%s' "$DOCKER_REGISTRY_PASSWORD" | docker login "$DOCKER_REGISTRY" \
  --username "$DOCKER_REGISTRY_USER" --password-stdin
docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"
docker push "$REMOTE_IMAGE"
