#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

runners=()
while IFS= read -r line; do
    runners+=("$line")
done < <(find . -maxdepth 2 -name '.env' -type f | sed 's|^\./||;s|/\.env$||' | sort)

if [[ ${#runners[@]} -eq 0 ]]; then
    echo "No runners found." >&2
    exit 1
fi

echo "Select a runner to follow logs:"
echo ""
echo "  0) all runners"
for i in "${!runners[@]}"; do
    echo "  $((i + 1))) runner-${runners[$i]}"
done
echo ""

while true; do
    read -rp "Choose [0-${#runners[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 ]] && [[ "$choice" -le ${#runners[@]} ]]; then
        break
    fi
    echo "Please enter a number between 0 and ${#runners[@]}"
done

echo ""
if [[ "$choice" -eq 0 ]]; then
    echo "Following all runners..."
    # docker logs cannot multiplex; use a loop with & and wait
    pids=()
    for r in "${runners[@]}"; do
        docker logs -f "runner-${r}" --timestamps 2>&1 | sed "s/^/[runner-${r}] /" &
        pids+=($!)
    done
    trap 'kill "${pids[@]}" 2>/dev/null; exit' INT TERM
    wait
else
    r="${runners[$((choice - 1))]}"
    echo "Following runner-${r}..."
    docker logs -f "runner-${r}"
fi
