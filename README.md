# GitHub Actions Self-Hosted Runner Manager

Manage multiple GitHub Actions self-hosted runners on a single machine using Docker Compose.

Each runner is defined by a simple `.env` file in its own directory. A single `docker-compose.yml` is auto-generated from all runner configs.

## Quick Start

```bash
# 1. Install dependencies (Docker, Docker Compose, just)
./setup.sh

# 2. Create a new runner (interactive)
just new

# 3. Start all runners
just up
```

## Commands

| Command        | Description                              |
|----------------|------------------------------------------|
| `just new`     | Interactive wizard to add a new runner   |
| `just up`      | Generate compose file and start runners  |
| `just down`    | Stop all runners                         |
| `just restart`  | Regenerate and restart all runners       |
| `just status`  | Show running containers                  |
| `just logs`    | Interactive log viewer                   |
| `just validate`| Check all `.env` files for required vars |
| `just generate`| Regenerate `docker-compose.yml`          |

## File Structure

```
├── setup.sh              # Install dependencies
├── justfile              # Task runner commands
├── .env.template         # Template for new runners
├── .gitignore            # Excludes .env files and docker-compose.yml
├── scripts/
│   ├── validate.sh       # Validate runner .env files
│   ├── generate.sh       # Generate docker-compose.yml
│   ├── up.sh             # Generate + start runners
│   ├── new.sh            # Interactive new runner setup
│   └── logs.sh           # Interactive log viewer
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

## Requirements

- Docker with Compose plugin
- [just](https://github.com/casey/just) command runner

Run `./setup.sh` to install everything automatically.
