#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REQUIRED_VARS=(REPO_URL RUNNER_TOKEN RUNNER_SCOPE RUNNER_NAME LABELS)
errors=0

for envfile in */.env; do
    [[ -f "$envfile" ]] || continue
    dirname="$(dirname "$envfile")"
    missing=()

    for var in "${REQUIRED_VARS[@]}"; do
        val="$(grep -E "^${var}=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || true
        if [[ -z "$val" ]]; then
            missing+=("$var")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "[OK] $dirname"
    else
        echo "[ERROR] $dirname — missing: ${missing[*]}"
        errors=1
    fi
done

if [[ $errors -ne 0 ]]; then
    exit 1
fi
