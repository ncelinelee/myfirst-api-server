#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
USER_NAME="${STUDENT_NUM:-local}"
IMAGE_NAME="webserver"
VERSION="1.0"
./mvnw --batch-mode verify
docker build --tag "${USER_NAME}-${IMAGE_NAME}:${VERSION}" --file Dockerfile .
