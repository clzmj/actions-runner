#!/bin/bash

# Read sensitive input (token/password) with asterisks
# Shows * for each character typed. Press Tab to reveal the input.
# Usage: read_sensitive "prompt" — sets global $SENSITIVE_INPUT
read_sensitive() {
    local prompt="$1"
    local input=""

    printf "%s" "$prompt"

    # Turn off echo (hide what user types)
    stty -echo 2>/dev/null || true

    local char
    while IFS= read -r -n 1 char 2>/dev/null || [[ -n "$char" ]]; do
        case "$char" in
            $'\t')  # Tab — reveal what was typed
                stty echo 2>/dev/null || true
                printf "\n"
                printf "You typed: %s\n" "$input"
                printf "%s" "$prompt"
                stty -echo 2>/dev/null || true
                ;;
            $'\n'|'')  # Enter or EOF — done
                stty echo 2>/dev/null || true
                [[ -n "$char" ]] && printf "\n"
                SENSITIVE_INPUT="$input"
                return 0
                ;;
            $'\177')  # Backspace (ASCII 127)
                if [[ ${#input} -gt 0 ]]; then
                    input="${input%?}"
                    printf "\b \b"
                fi
                ;;
            *)  # Regular character — add to input, show asterisk
                input+="$char"
                printf "*"
                ;;
        esac
    done

    # Restore echo
    stty echo 2>/dev/null || true
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
