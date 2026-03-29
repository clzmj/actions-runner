#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

# Find all runners
runners=()
while IFS= read -r line; do
    runners+=("$line")
done < <(find . -maxdepth 2 -name '.env' -type f | sed 's|^\./||;s|/\.env$||' | sort)

if [[ ${#runners[@]} -eq 0 ]]; then
    echo -e "${RED}✗${NC} No runners found." >&2
    exit 1
fi

echo ""
echo -e "${CYAN}${BOLD}Modify Runner${NC}"
echo ""

runners_str="${runners[*]}"
select_one "runner to modify" "$runners_str"
old_dir="$SELECTED_ITEM"
runner="$old_dir"
env_file="${runner}/.env"
old_container="runner-${old_dir}"

# Load current values
load_runner_env "$env_file"

echo ""
echo -e "${CYAN}${BOLD}${runner}${NC}"
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    echo -e "  Scope:   ${RUNNER_SCOPE}"
    echo -e "  Org:     ${ORG_NAME}"
else
    echo -e "  Scope:   ${RUNNER_SCOPE}"
    echo -e "  URL:     ${REPO_URL}"
fi
echo -e "  Name:    ${RUNNER_NAME}"
echo -e "  Labels:  ${LABELS}"
echo -e "  CPU:     ${CPU_LIMIT} cores"
echo -e "  Memory:  ${MEMORY_LIMIT}"
echo -e "  Workdir: ${RUNNER_WORKDIR}"
echo ""
echo -e "${GRAY}Press Enter to keep current values.${NC}"
echo ""

# Step 1: Runner scope
echo "Runner scope:"
echo "  1) org   — register to an organization"
echo "  2) repo  — register to a single repository"
while true; do
    read -rp "Choose [${RUNNER_SCOPE}]: " scope_choice
    if [[ -z "$scope_choice" ]]; then
        break
    fi
    case "$scope_choice" in
        1|org) RUNNER_SCOPE="org"; break ;;
        2|repo) RUNNER_SCOPE="repo"; break ;;
        *) echo "Please enter 1 (org) or 2 (repo)" ;;
    esac
done

# Step 2: Org name or Repo URL
echo ""
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    read -rp "Organization name [${ORG_NAME}]: " new_org
    ORG_NAME="${new_org:-$ORG_NAME}"
    REPO_URL=""
else
    read -rp "Repository URL [${REPO_URL}]: " new_url
    REPO_URL="${new_url:-$REPO_URL}"
    ORG_NAME=""
fi

# Step 3: Authentication
echo ""
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    echo "Authentication:"
    if [[ -n "$ACCESS_TOKEN" ]]; then
        echo -e "  Current: ${GRAY}Access token (PAT)${NC}"
    else
        echo -e "  Current: ${GRAY}Runner token${NC}"
    fi
    echo "  1) Keep current"
    echo "  2) Runner token  — short-lived, from org settings UI"
    echo "  3) Access token  — PAT, auto-refreshes"
    while true; do
        read -rp "Choose [1/2/3]: " auth_choice
        case "$auth_choice" in
            1|"")
                break
                ;;
            2)
                echo ""
                echo "Get your token from: https://github.com/organizations/${ORG_NAME}/settings/actions/runners/new"
                read_sensitive "Runner token: "
                RUNNER_TOKEN="$SENSITIVE_INPUT"
                ACCESS_TOKEN=""
                break
                ;;
            3)
                echo ""
                echo "Get a PAT from: https://github.com/settings/tokens"
                echo "Scopes: admin:org"
                read_sensitive "Access token (PAT): "
                ACCESS_TOKEN="$SENSITIVE_INPUT"
                RUNNER_TOKEN=""
                break
                ;;
            *)
                echo "Please enter 1, 2, or 3"
                ;;
        esac
    done
else
    echo "Get your token from: ${REPO_URL}/settings/actions/runners/new"
    echo -e "${GRAY}(press Enter to keep existing token)${NC}"
    read_sensitive "Runner token: "
    if [[ -n "$SENSITIVE_INPUT" ]]; then
        RUNNER_TOKEN="$SENSITIVE_INPUT"
    fi
    ACCESS_TOKEN=""
fi

# Step 4: Runner name
echo ""
read -rp "Runner name [${RUNNER_NAME}]: " new_name
RUNNER_NAME="${new_name:-$RUNNER_NAME}"

# Step 5: Labels
echo ""
read -rp "Labels [${LABELS}]: " new_labels
LABELS="${new_labels:-$LABELS}"

# Step 6: Resource limits
echo ""
read -rp "CPU limit in cores [${CPU_LIMIT}]: " new_cpu
CPU_LIMIT="${new_cpu:-$CPU_LIMIT}"

read -rp "Memory limit [${MEMORY_LIMIT}]: " new_memory
MEMORY_LIMIT="${new_memory:-$MEMORY_LIMIT}"

# Step 7: Work directory
echo ""
read -rp "Runner workdir [${RUNNER_WORKDIR}]: " new_workdir
RUNNER_WORKDIR="${new_workdir:-$RUNNER_WORKDIR}"

# Handle runner name change (rename directory)
if [[ "$old_dir" != "$RUNNER_NAME" ]]; then
    if [[ -d "$RUNNER_NAME" ]]; then
        echo -e "${RED}✗${NC} Directory '$RUNNER_NAME' already exists" >&2
        exit 1
    fi
    echo ""
    echo -e "${GRAY}Renaming ${old_dir} → ${RUNNER_NAME}...${NC}"
    mv "$old_dir" "$RUNNER_NAME"
    runner="$RUNNER_NAME"
    env_file="${runner}/.env"
fi

# Write .env file
mkdir -p "$runner"

if [[ "$RUNNER_SCOPE" == "org" ]]; then
    cat > "$env_file" <<EOF
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
        echo "RUNNER_TOKEN=${RUNNER_TOKEN}" >> "$env_file"
    fi
    if [[ -n "$ACCESS_TOKEN" ]]; then
        echo "ACCESS_TOKEN=${ACCESS_TOKEN}" >> "$env_file"
    fi
else
    cat > "$env_file" <<EOF
RUNNER_SCOPE=${RUNNER_SCOPE}
REPO_URL=${REPO_URL}
RUNNER_TOKEN=${RUNNER_TOKEN}
RUNNER_NAME=${RUNNER_NAME}
LABELS=${LABELS}
RUNNER_WORKDIR=${RUNNER_WORKDIR}
CPU_LIMIT=${CPU_LIMIT}
MEMORY_LIMIT=${MEMORY_LIMIT}
DISABLE_AUTOMATIC_DEREGISTRATION=true
EOF
fi

# Restart container
new_container="runner-${runner}"

echo ""
echo -e "${GRAY}Restarting ${CYAN}${new_container}${GRAY}...${NC}"

# Stop and remove old container
if docker inspect "$old_container" &>/dev/null; then
    docker stop "$old_container" 2>/dev/null || true
    docker rm "$old_container" 2>/dev/null || true
fi

# Create data directory if needed
if [[ -n "$RUNNER_NAME" ]]; then
    mkdir -p "/runner/data/${RUNNER_NAME}"
fi

# Start new container
docker run -d \
    --name "$new_container" \
    --restart unless-stopped \
    --env-file "${env_file}" \
    --env "RUNNER_WORKDIR=${RUNNER_WORKDIR}" \
    --env "CONFIGURED_ACTIONS_RUNNER_FILES_DIR=/runner/data/${RUNNER_NAME}" \
    --cpus "${CPU_LIMIT}" \
    --memory "${MEMORY_LIMIT}" \
    --security-opt label:disable \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "/runner/data/${RUNNER_NAME}:/runner/data/${RUNNER_NAME}" \
    -v "${RUNNER_WORKDIR}:${RUNNER_WORKDIR}" \
    myoung34/github-runner:latest

echo ""
echo -e "${GREEN}✓${NC} ${CYAN}${BOLD}Runner Updated${NC}"
echo "  Name:    ${RUNNER_NAME}"
echo "  Scope:   ${RUNNER_SCOPE}"
if [[ "$RUNNER_SCOPE" == "org" ]]; then
    echo "  Org:     ${ORG_NAME}"
else
    echo "  URL:     ${REPO_URL}"
fi
echo "  Labels:  ${LABELS}"
echo "  CPU:     ${CPU_LIMIT} cores"
echo "  Memory:  ${MEMORY_LIMIT}"
echo "  Workdir: ${RUNNER_WORKDIR}"
echo ""
