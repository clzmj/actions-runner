default: help

help:
    just --list

validate:
    bash scripts/validate.sh

up:
    bash scripts/up.sh

down:
    bash scripts/down.sh

restart:
    bash scripts/restart.sh

status:
    bash scripts/status.sh

logs:
    bash scripts/logs.sh

new:
    bash scripts/new.sh

describe:
    bash scripts/describe.sh

modify:
    bash scripts/modify.sh

remove:
    bash scripts/remove.sh
