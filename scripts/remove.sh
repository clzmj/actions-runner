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
    echo "No runners found." >&2
    exit 1
fi

echo ""
echo -e "${CYAN}${BOLD}Remove Runner${NC}"
echo ""
echo -e "${GRAY}Available runners:${NC}"
for i in "${!runners[@]}"; do
    printf "${GRAY}%2d${NC}. %s\n" $((i+1)) "${runners[$i]}"
done
echo ""

while true; do
    read -rp "Select runner to remove (1-${#runners[@]}): " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#runners[@]} ]]; then
        break
    fi
    echo -e "${RED}Invalid selection${NC}"
done

runner="${runners[$((selection-1))]}"
container="runner-${runner}"

echo ""
echo -e "${YELLOW}WARNING: This will permanently remove:${NC}"
echo -e "  Container: ${container}"
echo -e "  Directory: ${runner}/"
echo ""
read -rp "Type the runner name to confirm (${runner}): " confirm

if [[ "$confirm" != "$runner" ]]; then
    echo -e "${RED}Aborted — name did not match${NC}"
    exit 1
fi

# Stop and remove container
if docker inspect "$container" &>/dev/null; then
    echo "Stopping ${container}..."
    docker stop "$container" 2>/dev/null || true
    echo "Removing ${container}..."
    docker rm "$container" 2>/dev/null || true
else
    echo "(Container ${container} not found — skipping docker steps)"
fi

# Get the actual RUNNER_NAME from .env for data path
runner_name="$(grep -E "^RUNNER_NAME=" "${runner}/.env" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || runner_name="$runner"

# Remove directory
echo "Removing directory ${runner}/..."
rm -rf "${runner}"

echo ""
echo -e "${GREEN}✓${NC} Runner ${CYAN}${runner}${NC} removed."
echo -e "${GRAY}Note: runner data was NOT deleted.${NC}"
echo -e "${GRAY}To remove it: sudo rm -rf /runner/data/${runner_name}${NC}"
echo ""
