#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}Restart Runners${NC}"
echo ""
echo "  1) Restart all runners"
echo "  2) Restart a specific runner"
echo ""

while true; do
    read -rp "Choose [1/2]: " choice
    case "$choice" in
        1) mode="all"; break ;;
        2) mode="one"; break ;;
        *) echo -e "${RED}Please enter 1 or 2${NC}" ;;
    esac
done

if [[ "$mode" == "all" ]]; then
    # Restart all: just ensure all are running (same as `just up`)
    bash scripts/up.sh
else
    # Restart one: pick a runner and cycle it
    runners=()
    while IFS= read -r line; do
        runners+=("$line")
    done < <(find . -maxdepth 2 -name '.env' -type f | sed 's|^\./||;s|/\.env$||' | sort)

    if [[ ${#runners[@]} -eq 0 ]]; then
        echo "No runners found." >&2
        exit 1
    fi

    echo ""
    runners_str="${runners[*]}"
    select_one "runner to restart" "$runners_str"
    dirname="$SELECTED_ITEM"
    container="runner-${dirname}"
    env_file="${dirname}/.env"

    load_runner_env "$env_file"

    if docker inspect "$container" &>/dev/null; then
        echo "Stopping ${container}..."
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi

    # Create data directory if needed
    if [[ -n "$RUNNER_NAME" ]]; then
        mkdir -p "/runner/data/${RUNNER_NAME}"
    fi

    echo "Starting ${container}..."
    docker run -d \
        --name "$container" \
        --restart unless-stopped \
        --env-file "$env_file" \
        --env "RUNNER_WORKDIR=${RUNNER_WORKDIR}" \
        --env "CONFIGURED_ACTIONS_RUNNER_FILES_DIR=/runner/data/${RUNNER_NAME}" \
        --cpus "${CPU_LIMIT}" \
        --memory "${MEMORY_LIMIT}" \
        --security-opt label:disable \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "/runner/data/${RUNNER_NAME}:/runner/data/${RUNNER_NAME}" \
        -v "${RUNNER_WORKDIR}:${RUNNER_WORKDIR}" \
        myoung34/github-runner:latest

    echo "Done."
fi
