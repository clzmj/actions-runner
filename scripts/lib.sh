#!/bin/bash

# Shared function to load runner .env file and parse all config values
# Usage: load_runner_env "/path/to/.env"
# Sets globals: REPO_URL RUNNER_TOKEN RUNNER_SCOPE RUNNER_NAME LABELS
#               CPU_LIMIT MEMORY_LIMIT RUNNER_WORKDIR

load_runner_env() {
    local envfile="$1"

    # Initialize with defaults
    REPO_URL=""
    RUNNER_TOKEN=""
    RUNNER_SCOPE=""
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
            RUNNER_SCOPE)   RUNNER_SCOPE="$val" ;;
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
