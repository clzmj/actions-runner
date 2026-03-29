#!/bin/bash

# Read sensitive input (token/password) with hidden input
# Input is hidden as user types. Shows asterisks for verification after Enter.
# Usage: read_sensitive "prompt" — sets global $SENSITIVE_INPUT
read_sensitive() {
    local prompt="$1"
    printf "%s" "$prompt"

    # Read input without echo (hidden)
    read -rs input
    printf "\n"

    # Show verification (asterisks matching length)
    printf "  (entered: %s)\n" "$(printf '*%.0s' $(seq 1 ${#input}))"

    SENSITIVE_INPUT="$input"
}

# Shared function to load runner .env file and parse all config values
# Usage: load_runner_env "/path/to/.env"
# Sets globals: REPO_URL RUNNER_TOKEN RUNNER_SCOPE RUNNER_NAME LABELS
#               CPU_LIMIT MEMORY_LIMIT RUNNER_WORKDIR ORG_NAME ACCESS_TOKEN

load_runner_env() {
    local envfile="$1"

    # Initialize with defaults
    REPO_URL=""
    RUNNER_TOKEN=""
    ACCESS_TOKEN=""
    RUNNER_SCOPE=""
    ORG_NAME=""
    RUNNER_NAME=""
    LABELS=""
    CPU_LIMIT="1.0"
    MEMORY_LIMIT="1g"
    RUNNER_WORKDIR=""

    # Parse the env file
    local key val
    while IFS='=' read -r key val; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        # Trim whitespace
        key="$(printf '%s' "$key" | xargs)"
        val="$(printf '%s' "$val" | sed 's/#.*//' | xargs)"

        # Use case statement instead of declare for safety
        case "$key" in
            REPO_URL)       REPO_URL="$val" ;;
            RUNNER_TOKEN)   RUNNER_TOKEN="$val" ;;
            ACCESS_TOKEN)   ACCESS_TOKEN="$val" ;;
            RUNNER_SCOPE)   RUNNER_SCOPE="$val" ;;
            ORG_NAME)       ORG_NAME="$val" ;;
            RUNNER_NAME)    RUNNER_NAME="$val" ;;
            LABELS)         LABELS="$val" ;;
            CPU_LIMIT)      CPU_LIMIT="$val" ;;
            MEMORY_LIMIT)   MEMORY_LIMIT="$val" ;;
            RUNNER_WORKDIR) RUNNER_WORKDIR="$val" ;;
        esac
    done < "$envfile"

    # Apply defaults
    RUNNER_WORKDIR="${RUNNER_WORKDIR:-/tmp/runner/${RUNNER_NAME}}"
}

# Multi-select from a list with simple interface
# Usage: select_items "label" "items"
# Input: items as space-separated string
# Sets globals: SELECTED_ITEMS (array of chosen items), SELECTED_INDICES (array of indices)
select_items() {
    local label="$1"
    local items_str="$2"

    # Convert string to array
    read -ra items <<< "$items_str"

    if [[ ${#items[@]} -eq 0 ]]; then
        return 1
    fi

    echo "Select $label:"
    for i in "${!items[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${items[$i]}"
    done
    echo ""

    # Get selection
    while true; do
        read -rp "Enter numbers (comma/space-separated) or 'all', or Ctrl-C to cancel: " selection

        SELECTED_ITEMS=()
        SELECTED_INDICES=()

        # Check for "all"
        if [[ "$selection" == "all" ]]; then
            SELECTED_ITEMS=("${items[@]}")
            for ((i=0; i<${#items[@]}; i++)); do
                SELECTED_INDICES+=($i)
            done
            return 0
        fi

        # Parse comma or space-separated numbers
        local valid=1
        local numbers=$(echo "$selection" | tr ',' ' ' | tr -s ' ')

        for num in $numbers; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#items[@]} ]]; then
                SELECTED_ITEMS+=("${items[$((num - 1))]}")
                SELECTED_INDICES+=($(( num - 1 )))
            else
                valid=0
                break
            fi
        done

        if [[ $valid -eq 1 && ${#SELECTED_ITEMS[@]} -gt 0 ]]; then
            return 0
        fi

        echo "Invalid input. Please enter numbers (1-${#items[@]}) separated by commas/spaces, or 'all'."
    done
}
