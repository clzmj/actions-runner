# GitHub Actions Self-Hosted Runner Manager

Manage multiple GitHub Actions self-hosted runners on a single machine with isolated, independent Docker containers.

Each runner is defined by a simple `.env` file in its own directory. Containers are managed independently — modifying or restarting one runner never affects others.

## Quick Start

```bash
# 1. Install dependencies (Docker, just)
./setup.sh

# 2. Create a new runner (interactive — starts immediately)
just new

# 3. View all runners
just describe
```

## Commands

| Command        | Description                              |
|----------------|------------------------------------------|
| `just new`     | Interactive wizard to add a new runner (starts immediately) |
| `just up`      | Ensure all configured runners are running (idempotent) |
| `just down`    | Interactive: select which runners to stop |
| `just restart` | Interactive: restart all runners or a specific one |
| `just status`  | Show running containers                  |
| `just logs`    | Interactive log viewer (single or all)   |
| `just describe`| List all runners with live status        |
| `just modify`  | Interactive: change CPU/memory and restart runner |
| `just remove`  | Interactive: permanently delete a runner |
| `just validate`| Check all `.env` files for required vars |

## File Structure

```
├── setup.sh              # Install dependencies
├── justfile              # Task runner commands
├── .env.template         # Template for new runners
├── .gitignore            # Excludes .env files
├── scripts/
│   ├── lib.sh            # Shared config loader
│   ├── validate.sh       # Validate runner .env files
│   ├── up.sh             # Start all configured runners
│   ├── down.sh           # Interactive: stop selected runners
│   ├── new.sh            # Interactive new runner setup + start
│   ├── restart.sh        # Interactive: restart all or one runner
│   ├── modify.sh         # Modify runner CPU/memory
│   ├── remove.sh         # Interactive: delete a runner
│   ├── status.sh         # Show running containers
│   ├── logs.sh           # Interactive log viewer
│   └── describe.sh       # Display runner configurations
└── <runner-name>/        # One directory per runner
    └── .env              # Runner configuration (git-ignored)
```

## Runner `.env` Configuration

```bash
REPO_URL=https://github.com/your-org          # org or repo URL
RUNNER_TOKEN=AXXXXXXX                          # from GitHub settings
RUNNER_SCOPE=org                               # org | repo
RUNNER_NAME=my-runner
LABELS=linux,x64
RUNNER_WORKDIR=/tmp/runner/my-runner           # optional, auto-defaults
CPU_LIMIT=1.0                                  # optional, default 1.0
MEMORY_LIMIT=1g                                # optional, default 1g
DISABLE_AUTOMATIC_DEREGISTRATION=true
```

Get your runner token from: **Settings > Actions > Runners > New self-hosted runner**

## Key Design: Independent Containers

Each runner runs as a standalone Docker container named `runner-<dirname>`. This means:

- **Isolation**: Adding, modifying, or restarting one runner never affects others.
- **No service mesh**: No docker-compose orchestration layer. Containers manage themselves.
- **Safe updates**: `just modify` only cycles the target runner. `just up` is idempotent — it only starts runners that are not already running.
- **Interactive control**: Commands like `just down`, `just remove`, `just restart-one` use guided flows to prevent accidental changes.

## Requirements

- Docker with Compose plugin
- [just](https://github.com/casey/just) command runner

Run `./setup.sh` to install everything automatically.
