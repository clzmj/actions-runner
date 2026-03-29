default: describe

# Show this help message
help:
    just --list

# Validate all runner .env files for required variables
validate:
    bash scripts/validate.sh

# Ensure all configured runners are running (idempotent, safe)
up:
    bash scripts/up.sh

# Interactive: select which runners to stop
down:
    bash scripts/down.sh

# Interactive: restart all runners or pick a specific one
restart:
    bash scripts/restart.sh

# Show running containers with status and uptime
status:
    bash scripts/status.sh

# Interactive: follow logs from a runner (single or all)
logs:
    bash scripts/logs.sh

# Interactive: create and immediately start a new runner
new:
    bash scripts/new.sh

# Display all runners with configuration and live status
describe:
    bash scripts/describe.sh

# Interactive: change CPU/memory limits and restart a runner
modify:
    bash scripts/modify.sh

# Interactive: permanently delete a runner and its directory
remove:
    bash scripts/remove.sh
