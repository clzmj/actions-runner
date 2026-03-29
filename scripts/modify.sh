#!/bin/bash

set -euo pipefail

# Colors
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'
NC='\033[0m'

cd "$(dirname "$0")/.."
source scripts/lib.sh

# Find all runners
runners=()
while IFS= read -r line; do
    runners+=("$line")
done < <(find . -maxdepth 2 -name '.env' -type f | sed 's|^\./||;s|/\.env$||' | sort)

if [ ${#runners[@]} -eq 0 ]; then
    echo "No runners found."
    exit 1
fi

echo ""
echo -e "${CYAN}${BOLD}Modify Runner Resources${NC}"
echo ""

runners_str="${runners[*]}"
select_one "runner to modify" "$runners_str"
runner="$SELECTED_ITEM"
env_file="${runner}/.env"

# Load current values
load_runner_env "$env_file"

echo ""
echo -e "${CYAN}${BOLD}${runner}${NC}"
echo -e "  Current CPU:    ${GREEN}${CPU_LIMIT}${NC} cores"
echo -e "  Current Memory: ${GREEN}${MEMORY_LIMIT}${NC}"
echo ""

# Get CPU limit
while true; do
    read -p "Enter CPU limit (e.g., 0.5, 1.0, 2.0) [${GREEN}${CPU_LIMIT}${NC}]: " new_cpu
    new_cpu="${new_cpu:-$CPU_LIMIT}"

    if [[ "$new_cpu" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$new_cpu > 0" | bc -l) )); then
        break
    fi
    echo -e "${RED}Invalid CPU value${NC}"
done

# Get memory limit
while true; do
    read -p "Enter memory limit (e.g., 512m, 1g, 2g) [${GREEN}${MEMORY_LIMIT}${NC}]: " new_memory
    new_memory="${new_memory:-$MEMORY_LIMIT}"

    if [[ "$new_memory" =~ ^[0-9]+(m|g)$ ]]; then
        break
    fi
    echo -e "${RED}Invalid memory value${NC}"
done

echo ""
echo -e "${GRAY}Applying changes to ${CYAN}runner-${runner}${GRAY}...${NC}"

# Update .env file
if grep -q "^CPU_LIMIT=" "$env_file"; then
    sed -i "" "s/^CPU_LIMIT=.*/CPU_LIMIT=$new_cpu/" "$env_file"
else
    echo "CPU_LIMIT=$new_cpu" >> "$env_file"
fi

if grep -q "^MEMORY_LIMIT=" "$env_file"; then
    sed -i "" "s/^MEMORY_LIMIT=.*/MEMORY_LIMIT=$new_memory/" "$env_file"
else
    echo "MEMORY_LIMIT=$new_memory" >> "$env_file"
fi

# Re-read updated env to get all values for docker run
load_runner_env "$env_file"

container="runner-${runner}"

# Stop and remove the existing container
if docker inspect "$container" &>/dev/null; then
    docker stop "$container" 2>/dev/null || true
    docker rm "$container" 2>/dev/null || true
fi

# Create data directory if needed
if [[ -n "$RUNNER_NAME" ]]; then
    mkdir -p "/runner/data/${RUNNER_NAME}"
fi

# Recreate the container with new resource limits
docker run -d \
    --name "$container" \
    --restart unless-stopped \
    --env-file "${runner}/.env" \
    --env "RUNNER_WORKDIR=${RUNNER_WORKDIR}" \
    --env "CONFIGURED_ACTIONS_RUNNER_FILES_DIR=/runner/data/${RUNNER_NAME}" \
    --cpus "${CPU_LIMIT}" \
    --memory "${MEMORY_LIMIT}" \
    --security-opt label:disable \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "/runner/data/${RUNNER_NAME}:/runner/data/${RUNNER_NAME}" \
    -v "${RUNNER_WORKDIR}:${RUNNER_WORKDIR}" \
    myoung34/github-runner:latest

echo -e "${GREEN}✓${NC} ${CYAN}runner-${runner}${NC} restarted with new limits"
echo -e "  CPU:    ${new_cpu} cores"
echo -e "  Memory: ${new_memory}"
echo ""
