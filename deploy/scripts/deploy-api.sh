#!/usr/bin/env bash

set -euo pipefail

readonly source_binary="${1:?usage: deploy-api.sh <cuit-server-api>}"
readonly target_binary="/usr/local/bin/cuit-server-api"
readonly backup_binary="/usr/local/bin/cuit-server-api.previous"
readonly staged_binary="/usr/local/bin/cuit-server-api.new"
readonly health_url="http://127.0.0.1:8888/api/v1/health"

if [[ ! -f "$source_binary" ]]; then
  echo "API binary not found: $source_binary" >&2
  exit 1
fi

install -o root -g root -m 0755 "$source_binary" "$staged_binary"

if [[ -f "$target_binary" ]]; then
  cp -p "$target_binary" "$backup_binary"
fi

mv -f "$staged_binary" "$target_binary"
systemctl restart cuit-server

for _ in {1..10}; do
  if curl --fail --silent --show-error "$health_url" >/dev/null; then
    echo "API deployment succeeded"
    exit 0
  fi
  sleep 1
done

echo "API health check failed; rolling back" >&2

if [[ -f "$backup_binary" ]]; then
  cp -p "$backup_binary" "$target_binary"
  systemctl restart cuit-server
fi

exit 1
