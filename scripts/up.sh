#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

bash scripts/validate.sh

for envfile in */.env; do
    [[ -f "$envfile" ]] || continue
    dirname="$(dirname "$envfile")"
    container="runner-${dirname}"

    load_runner_env "$envfile"

    # Create data directory
    if [[ -n "$RUNNER_NAME" ]]; then
        mkdir -p "/runner/data/${RUNNER_NAME}"
    fi

    # Skip if already running
    if docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null | grep -q '^true$'; then
        echo -e "${GRAY}[skip]${NC} $container is already running"
        continue
    fi

    # Remove stopped/exited container with same name (so we can recreate)
    if docker inspect "$container" &>/dev/null; then
        echo -e "${GRAY}[remove]${NC} Removing stopped container $container"
        docker rm "$container"
    fi

    echo -e "${GRAY}[start]${NC} $container"
    docker run -d \
        --name "$container" \
        --restart unless-stopped \
        --env-file "$envfile" \
        --env "RUNNER_WORKDIR=${RUNNER_WORKDIR}" \
        --env "CONFIGURED_ACTIONS_RUNNER_FILES_DIR=/runner/data/${RUNNER_NAME}" \
        --cpus "${CPU_LIMIT}" \
        --memory "${MEMORY_LIMIT}" \
        --security-opt label:disable \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "/runner/data/${RUNNER_NAME}:/runner/data/${RUNNER_NAME}" \
        -v "${RUNNER_WORKDIR}:${RUNNER_WORKDIR}" \
        myoung34/github-runner:latest
done

echo "Done."
