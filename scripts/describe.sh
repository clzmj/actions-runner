#!/bin/bash

# Colors for modern output
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
GRAY='\033[90m'
NC='\033[0m'

# Get all service names from docker-compose.yml
services=$(grep -E '^\s+runner-' docker-compose.yml | sed 's/.*runner-//' | sed 's/:$//')

if [ -z "$services" ]; then
    echo "No runners found in docker-compose.yml"
    exit 0
fi

# Column widths
col1=27  # RUNNER
col2=32  # REPO
col3=8   # CPU
col4=10  # MEMORY
col5=8   # SCOPE
col6=22  # LABELS

# Print title
echo ""
echo -e "${CYAN}${BOLD}GitHub Actions Runners${NC}"
echo ""

# Print header
printf "${GRAY}"
printf "%-${col1}s  %-${col2}s  %-${col3}s  %-${col4}s  %-${col5}s  %-${col6}s\n" \
    "RUNNER" "REPO" "CPU" "MEMORY" "SCOPE" "LABELS"

# Print separator
printf "%s  %s  %s  %s  %s  %s\n" \
    "$(printf '━%.0s' $(seq 1 $col1))" \
    "$(printf '━%.0s' $(seq 1 $col2))" \
    "$(printf '━%.0s' $(seq 1 $col3))" \
    "$(printf '━%.0s' $(seq 1 $col4))" \
    "$(printf '━%.0s' $(seq 1 $col5))" \
    "$(printf '━%.0s' $(seq 1 $col6))"
printf "${NC}"

# Process each runner
count=0
for service in $services; do
    runner_name="runner-$service"
    env_file="${service}/.env"

    if [ ! -f "$env_file" ]; then
        continue
    fi

    count=$((count + 1))

    # Extract values from .env file
    repo=$(grep "^REPO_URL=" "$env_file" | cut -d'=' -f2 | xargs basename 2>/dev/null)
    scope=$(grep "^RUNNER_SCOPE=" "$env_file" | cut -d'=' -f2)
    labels=$(grep "^LABELS=" "$env_file" | cut -d'=' -f2)

    # Extract CPU and memory from docker-compose.yml
    cpu=$(grep -A 30 "^  $runner_name:" docker-compose.yml | grep "cpus:" | sed "s/.*cpus: '//;s/'.*//")
    memory=$(grep -A 30 "^  $runner_name:" docker-compose.yml | grep "memory:" | sed "s/.*memory: //")

    # Set defaults if not found
    cpu="${cpu:-N/A}"
    memory="${memory:-N/A}"
    repo="${repo:--}"
    scope="${scope:-N/A}"
    labels="${labels:-N/A}"

    # Truncate long values
    repo_short="${repo:0:$((col2-1))}"
    labels_short="${labels:0:$((col6-1))}"

    # Color code based on status
    status_color="${GREEN}"

    # Print row with alternating subtle background effect
    if [ $((count % 2)) -eq 0 ]; then
        printf "${GRAY}"
    fi

    printf "%-${col1}s  %-${col2}s  ${status_color}%-${col3}s${NC}${GRAY}  %-${col4}s  %-${col5}s  %-${col6}s${NC}\n" \
        "$service" "$repo_short" "$cpu" "$memory" "$scope" "$labels_short"
done

echo ""
