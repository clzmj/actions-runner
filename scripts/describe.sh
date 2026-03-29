#!/bin/bash
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

col1=27  # RUNNER
col2=32  # REPO
col3=8   # CPU
col4=10  # MEMORY
col5=8   # SCOPE
col6=22  # LABELS
col7=10  # STATUS

runners=()
while IFS= read -r line; do
    runners+=("$line")
done < <(find . -maxdepth 2 -name '.env' -type f | sed 's|^\./||;s|/\.env$||' | sort)

if [[ ${#runners[@]} -eq 0 ]]; then
    echo "No runners found."
    exit 0
fi

echo ""
echo -e "${CYAN}${BOLD}GitHub Actions Runners${NC}"
echo ""

printf "${GRAY}"
printf "%-${col1}s  %-${col2}s  %-${col3}s  %-${col4}s  %-${col5}s  %-${col6}s  %-${col7}s\n" \
    "RUNNER" "REPO" "CPU" "MEMORY" "SCOPE" "LABELS" "STATUS"
printf "%s  %s  %s  %s  %s  %s  %s\n" \
    "$(printf '━%.0s' $(seq 1 $col1))" \
    "$(printf '━%.0s' $(seq 1 $col2))" \
    "$(printf '━%.0s' $(seq 1 $col3))" \
    "$(printf '━%.0s' $(seq 1 $col4))" \
    "$(printf '━%.0s' $(seq 1 $col5))" \
    "$(printf '━%.0s' $(seq 1 $col6))" \
    "$(printf '━%.0s' $(seq 1 $col7))"
printf "${NC}"

count=0
for dirname in "${runners[@]}"; do
    env_file="${dirname}/.env"
    [[ -f "$env_file" ]] || continue
    count=$((count + 1))

    load_runner_env "$env_file"

    repo="$(basename "$REPO_URL" 2>/dev/null || echo '-')"
    scope="${RUNNER_SCOPE:-N/A}"
    labels="${LABELS:-N/A}"
    cpu="${CPU_LIMIT:-N/A}"
    memory="${MEMORY_LIMIT:-N/A}"

    container="runner-${dirname}"
    # Get live status from docker
    status="$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo 'not found')"
    case "$status" in
        running)   status_display="${GREEN}running${NC}" ;;
        exited)    status_display="${RED}exited${NC}" ;;
        "not found") status_display="${GRAY}not found${NC}" ;;
        *)         status_display="${YELLOW}${status}${NC}" ;;
    esac

    repo_short="${repo:0:$((col2-1))}"
    labels_short="${labels:0:$((col6-1))}"

    if [[ $((count % 2)) -eq 0 ]]; then printf "${GRAY}"; fi

    printf "%-${col1}s  %-${col2}s  %-${col3}s  %-${col4}s  %-${col5}s  %-${col6}s  " \
        "$dirname" "$repo_short" "$cpu" "$memory" "$scope" "$labels_short"
    printf "${status_display}\n"
    printf "${NC}"
done

echo ""
