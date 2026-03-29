#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

bash scripts/generate.sh

# Create data dirs for each runner
for envfile in */.env; do
    [[ -f "$envfile" ]] || continue
    RUNNER_NAME="$(grep -E "^RUNNER_NAME=" "$envfile" | head -1 | cut -d= -f2- | xargs)"
    if [[ -n "$RUNNER_NAME" ]]; then
        mkdir -p "/runner/data/${RUNNER_NAME}"
    fi
done

docker compose up -d
