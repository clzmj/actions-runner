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

runners=()
while IFS= read -r line; do
    runners+=("$line")
done < <(find . -maxdepth 2 -name '.env' -type f | sed 's|^\./||;s|/\.env$||' | sort)

if [[ ${#runners[@]} -eq 0 ]]; then
    echo "No runners found."
    exit 0
fi

echo ""
echo -e "${CYAN}${BOLD}Stop Runners${NC}"
echo ""

# Use simple selection
runners_str="${runners[*]}"
select_items "runners to stop" "$runners_str"

echo ""
echo -e "${YELLOW}Will stop:${NC}"
for item in "${SELECTED_ITEMS[@]}"; do
    echo "  - runner-${item}"
done
echo ""

read -rp "Confirm (type 'yes' to proceed): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
for item in "${SELECTED_ITEMS[@]}"; do
    container="runner-${item}"
    if docker inspect "$container" &>/dev/null; then
        echo "Stopping ${container}..."
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi
done

echo -e "${GREEN}✓${NC} Done."
echo ""
