#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

errors=0

for envfile in */.env; do
    [[ -f "$envfile" ]] || continue
    dirname="$(dirname "$envfile")"
    missing=()

    # Always required
    for var in RUNNER_SCOPE RUNNER_NAME LABELS; do
        val="$(grep -E "^${var}=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || true
        if [[ -z "$val" ]]; then
            missing+=("$var")
        fi
    done

    # Check scope-specific requirements
    scope="$(grep -E "^RUNNER_SCOPE=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || true

    if [[ "$scope" == "org" ]]; then
        # Org scope: needs ORG_NAME and either RUNNER_TOKEN or ACCESS_TOKEN
        org_name="$(grep -E "^ORG_NAME=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || true
        runner_token="$(grep -E "^RUNNER_TOKEN=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || true
        access_token="$(grep -E "^ACCESS_TOKEN=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || true

        if [[ -z "$org_name" ]]; then
            missing+=("ORG_NAME")
        fi
        if [[ -z "$runner_token" && -z "$access_token" ]]; then
            missing+=("RUNNER_TOKEN or ACCESS_TOKEN")
        fi
    else
        # Repo scope: needs REPO_URL and RUNNER_TOKEN
        for var in REPO_URL RUNNER_TOKEN; do
            val="$(grep -E "^${var}=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | xargs)" || true
            if [[ -z "$val" ]]; then
                missing+=("$var")
            fi
        done
    fi

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo -e "${GREEN}[✓]${NC} $dirname"
    else
        echo -e "${RED}[✗]${NC} $dirname — missing: ${missing[*]}"
        errors=1
    fi
done

if [[ $errors -ne 0 ]]; then
    exit 1
fi
