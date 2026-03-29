#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

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

# Initialize selection array (0 = not selected, 1 = selected)
declare -a selected
for ((i=0; i<${#runners[@]}; i++)); do
    selected[$i]=0
done

# Helper to print menu with current selections
print_menu() {
    echo "Select runners to stop:"
    echo "  a) all runners"
    for i in "${!runners[@]}"; do
        if [[ ${selected[$i]} -eq 1 ]]; then
            status="${GREEN}[✓]${NC}"
        else
            status="[ ]"
        fi
        status_live="$(docker inspect --format '{{.State.Status}}' "runner-${runners[$i]}" 2>/dev/null || echo 'not found')"
        printf "  %d) ${status} runner-%-20s ${GRAY}[${status_live}]${NC}\n" $((i+1)) "${runners[$i]}"
    done
    echo ""
}

# Interactive loop
while true; do
    clear
    echo ""
    echo -e "${CYAN}${BOLD}Stop Runners${NC}"
    echo ""
    print_menu

    read -rp "Toggle (number), 'a' for all, or press enter to confirm: " choice

    if [[ -z "$choice" ]]; then
        # User pressed enter — check if at least one is selected
        any_selected=0
        for ((i=0; i<${#runners[@]}; i++)); do
            if [[ ${selected[$i]} -eq 1 ]]; then
                any_selected=1
                break
            fi
        done
        if [[ $any_selected -eq 0 ]]; then
            echo -e "${RED}No runners selected. Please select at least one or press Ctrl-C to cancel.${NC}"
            sleep 2
            continue
        fi
        break
    elif [[ "$choice" == "a" ]]; then
        # Select all
        for ((i=0; i<${#runners[@]}; i++)); do
            selected[$i]=1
        done
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#runners[@]} ]]; then
        # Toggle that runner
        idx=$((choice - 1))
        if [[ ${selected[$idx]} -eq 1 ]]; then
            selected[$idx]=0
        else
            selected[$idx]=1
        fi
    else
        echo -e "${RED}Invalid input.${NC}"
        sleep 1
    fi
done

echo ""
echo -e "${YELLOW}Will stop the following runners:${NC}"
for i in "${!runners[@]}"; do
    if [[ ${selected[$i]} -eq 1 ]]; then
        echo "  - runner-${runners[$i]}"
    fi
done
echo ""

read -rp "Confirm (type 'yes' to proceed): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
for i in "${!runners[@]}"; do
    if [[ ${selected[$i]} -eq 1 ]]; then
        container="runner-${runners[$i]}"
        if docker inspect "$container" &>/dev/null; then
            echo "Stopping ${container}..."
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        fi
    fi
done

echo -e "${GREEN}✓${NC} Done."
echo ""
