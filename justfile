default: help

help:
    just --list

validate:
    bash scripts/validate.sh

generate:
    bash scripts/generate.sh

up:
    bash scripts/up.sh

down:
    docker compose down

restart: generate
    docker compose restart

status:
    docker compose ps

logs:
    bash scripts/logs.sh

new:
    bash scripts/new.sh

describe:
    bash scripts/describe.sh
