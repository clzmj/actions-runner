#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Collect runner services from docker-compose.yml
if [[ ! -f docker-compose.yml ]]; then
    echo "No docker-compose.yml found. Run 'just generate' first." >&2
    exit 1
fi

mapfile -t services < <(grep -E '^\s+runner-' docker-compose.yml | sed 's/://' | xargs)

if [[ ${#services[@]} -eq 0 ]]; then
    echo "No runner services found in docker-compose.yml" >&2
    exit 1
fi

echo "Select a runner to follow logs:"
echo ""
echo "  0) all runners"
for i in "${!services[@]}"; do
    echo "  $((i + 1))) ${services[$i]}"
done
echo ""

while true; do
    read -rp "Choose [0-${#services[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 ]] && [[ "$choice" -le ${#services[@]} ]]; then
        break
    fi
    echo "Please enter a number between 0 and ${#services[@]}"
done

echo ""
if [[ "$choice" -eq 0 ]]; then
    echo "Following all runners..."
    docker compose logs -f
else
    svc="${services[$((choice - 1))]}"
    echo "Following ${svc}..."
    docker compose logs -f "$svc"
fi
