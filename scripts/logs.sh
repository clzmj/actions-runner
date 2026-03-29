#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

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
select_items "runner to follow (or 'all')" "$runners_str"

echo ""

# Check if all runners were selected
if [[ ${#SELECTED_ITEMS[@]} -eq ${#runners[@]} ]]; then
    echo "Following all runners..."
    # docker logs cannot multiplex; use a loop with & and wait
    pids=()
    for r in "${SELECTED_ITEMS[@]}"; do
        docker logs -f "runner-${r}" --timestamps 2>&1 | sed "s/^/[runner-${r}] /" &
        pids+=($!)
    done
    trap 'kill "${pids[@]}" 2>/dev/null; exit' INT TERM
    wait
else
    r="${SELECTED_ITEMS[0]}"
    echo "Following runner-${r}..."
    docker logs -f "runner-${r}"
fi
