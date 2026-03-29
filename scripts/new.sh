#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

echo "=== New GitHub Actions Runner Setup ==="
echo ""

# Step 1: Runner directory name
read -rp "Runner directory name (e.g. my-org, my-repo): " name
if [[ -z "$name" ]]; then
    echo "Error: name cannot be empty" >&2
    exit 1
fi
if [[ -d "$name" ]]; then
    echo "Error: directory '$name' already exists" >&2
    exit 1
fi

# Step 2: Runner scope
echo ""
echo "Runner scope:"
echo "  1) org   — register to an organization"
echo "  2) repo  — register to a single repository"
while true; do
    read -rp "Choose [1/2]: " scope_choice
    case "$scope_choice" in
        1) RUNNER_SCOPE="org"; break ;;
        2) RUNNER_SCOPE="repo"; break ;;
        *) echo "Please enter 1 or 2" ;;
    esac
done

# Step 3: Org name or Repo URL + Token
echo ""
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    read -rp "Organization name (e.g. my-org): " ORG_NAME
    if [[ -z "$ORG_NAME" ]]; then
        echo "Error: organization name cannot be empty" >&2
        exit 1
    fi

    # Step 4: Auth method for org scope
    echo ""
    echo "Authentication method:"
    echo "  1) Runner token  — short-lived, from org settings UI"
    echo "  2) Access token  — PAT, auto-refreshes (recommended)"
    while true; do
        read -rp "Choose [1/2]: " auth_method
        case "$auth_method" in
            1)
                echo ""
                echo "Get your token from: https://github.com/organizations/${ORG_NAME}/settings/actions/runners/new"
                read -rp "Runner token: " RUNNER_TOKEN
                if [[ -z "$RUNNER_TOKEN" ]]; then
                    echo "Error: runner token cannot be empty" >&2
                    exit 1
                fi
                ACCESS_TOKEN=""
                break
                ;;
            2)
                echo ""
                echo "Get a PAT from: https://github.com/settings/tokens"
                echo "Scopes: admin:org"
                read -rp "Access token (PAT): " ACCESS_TOKEN
                if [[ -z "$ACCESS_TOKEN" ]]; then
                    echo "Error: access token cannot be empty" >&2
                    exit 1
                fi
                RUNNER_TOKEN=""
                break
                ;;
            *)
                echo "Please enter 1 or 2"
                ;;
        esac
    done
else
    read -rp "Repository URL (e.g. https://github.com/user/repo): " REPO_URL
    if [[ -z "$REPO_URL" ]]; then
        echo "Error: URL cannot be empty" >&2
        exit 1
    fi

    # Step 4: Runner token (short-lived for repo scope)
    echo ""
    echo "Get your token from: ${REPO_URL}/settings/actions/runners/new"
    read -rp "Runner token: " RUNNER_TOKEN
    if [[ -z "$RUNNER_TOKEN" ]]; then
        echo "Error: token cannot be empty" >&2
        exit 1
    fi
fi

# Step 5: Runner name
echo ""
read -rp "Runner name [${name}]: " RUNNER_NAME
RUNNER_NAME="${RUNNER_NAME:-$name}"

# Step 6: Labels
echo ""
read -rp "Labels [linux,x64]: " LABELS
LABELS="${LABELS:-linux,x64}"

# Step 7: Resource limits
echo ""
read -rp "CPU limit in cores [1.0]: " CPU_LIMIT
CPU_LIMIT="${CPU_LIMIT:-1.0}"

read -rp "Memory limit [1g]: " MEMORY_LIMIT
MEMORY_LIMIT="${MEMORY_LIMIT:-1g}"

# Step 8: Work directory
echo ""
read -rp "Runner workdir [/tmp/runner/${RUNNER_NAME}]: " RUNNER_WORKDIR
RUNNER_WORKDIR="${RUNNER_WORKDIR:-/tmp/runner/${RUNNER_NAME}}"

# Write .env
mkdir -p "$name"

# Build .env content based on scope
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    cat > "$name/.env" <<EOF
RUNNER_SCOPE=${RUNNER_SCOPE}
ORG_NAME=${ORG_NAME}
RUNNER_NAME=${RUNNER_NAME}
LABELS=${LABELS}
RUNNER_WORKDIR=${RUNNER_WORKDIR}
CPU_LIMIT=${CPU_LIMIT}
MEMORY_LIMIT=${MEMORY_LIMIT}
DISABLE_AUTOMATIC_DEREGISTRATION=true
EOF
    if [[ -n "$RUNNER_TOKEN" ]]; then
        echo "RUNNER_TOKEN=${RUNNER_TOKEN}" >> "$name/.env"
    fi
    if [[ -n "$ACCESS_TOKEN" ]]; then
        echo "ACCESS_TOKEN=${ACCESS_TOKEN}" >> "$name/.env"
    fi
else
    cat > "$name/.env" <<EOF
REPO_URL=${REPO_URL}
RUNNER_TOKEN=${RUNNER_TOKEN}
RUNNER_SCOPE=${RUNNER_SCOPE}
RUNNER_NAME=${RUNNER_NAME}
LABELS=${LABELS}
RUNNER_WORKDIR=${RUNNER_WORKDIR}
CPU_LIMIT=${CPU_LIMIT}
MEMORY_LIMIT=${MEMORY_LIMIT}
DISABLE_AUTOMATIC_DEREGISTRATION=true
EOF
fi

echo ""
echo "=== Runner configured ==="
echo "  Directory:  ${name}/"
echo "  Name:       ${RUNNER_NAME}"
echo "  Scope:      ${RUNNER_SCOPE}"
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    echo "  Org:        ${ORG_NAME}"
    if [[ -n "$RUNNER_TOKEN" ]]; then
        echo "  Auth:       Runner token (short-lived)"
    else
        echo "  Auth:       Access token (PAT)"
    fi
else
    echo "  URL:        ${REPO_URL}"
fi
echo "  Labels:     ${LABELS}"
echo "  CPU:        ${CPU_LIMIT} cores"
echo "  Memory:     ${MEMORY_LIMIT}"
echo "  Workdir:    ${RUNNER_WORKDIR}"
echo ""

# Validate configuration
bash scripts/validate.sh

# Create data dir
mkdir -p "/runner/data/${RUNNER_NAME}"

container="runner-${name}"
echo "Starting ${container}..."
docker run -d \
    --name "$container" \
    --restart unless-stopped \
    --env-file "${name}/.env" \
    --env "RUNNER_WORKDIR=${RUNNER_WORKDIR}" \
    --env "CONFIGURED_ACTIONS_RUNNER_FILES_DIR=/runner/data/${RUNNER_NAME}" \
    --cpus "${CPU_LIMIT}" \
    --memory "${MEMORY_LIMIT}" \
    --security-opt label:disable \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "/runner/data/${RUNNER_NAME}:/runner/data/${RUNNER_NAME}" \
    -v "${RUNNER_WORKDIR}:${RUNNER_WORKDIR}" \
    myoung34/github-runner:latest

echo "Runner started. Use 'just status' to confirm."
