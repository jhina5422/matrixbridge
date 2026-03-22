#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
DATA_DIR="$ROOT_DIR/data"
CONFIG_TEMPLATE="$ROOT_DIR/config/config.sample.yaml"
OUTPUT_FILE="$DATA_DIR/discord-registration.yaml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy .env.example to .env first." >&2
  exit 1
fi

mkdir -p "$DATA_DIR"

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${MATRIX_HOMESERVER_URL:?Set MATRIX_HOMESERVER_URL in .env}"

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required to render config/config.sample.yaml. Install gettext first." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to generate the registration file." >&2
  exit 1
fi

cp "$CONFIG_TEMPLATE" "$DATA_DIR/config.rendered.yaml"
envsubst < "$DATA_DIR/config.rendered.yaml" > "$DATA_DIR/config.yaml"
rm "$DATA_DIR/config.rendered.yaml"

docker run --rm \
  -v "$DATA_DIR:/data" \
  halfshot/matrix-appservice-discord:latest \
  node build/src/discordas.js \
  -r \
  -u "${MATRIX_HOMESERVER_URL}" \
  -c /data/config.yaml

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "Expected registration file was not generated: $OUTPUT_FILE" >&2
  exit 1
fi

echo "Generated $OUTPUT_FILE"
