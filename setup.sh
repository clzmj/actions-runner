#!/usr/bin/env bash
set -euo pipefail

echo "=== GitHub Actions Runner Manager — Setup ==="
echo ""

# Detect OS
OS="unknown"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian)    OS="debian" ;;
        fedora)           OS="fedora" ;;
        centos|rhel|amzn) OS="rhel" ;;
        alpine)           OS="alpine" ;;
    esac
elif [[ "$(uname)" == "Darwin" ]]; then
    OS="macos"
fi

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)   ARCH="x86_64" ;;
    aarch64|arm64)   ARCH="arm64" ;;
esac

echo "Detected: OS=$OS ARCH=$ARCH"
echo ""

# ── Docker ──────────────────────────────────────────────
if command -v docker &>/dev/null; then
    echo "[skip] Docker already installed: $(docker --version)"
else
    echo "[install] Docker..."
    if [[ "$OS" == "macos" ]]; then
        echo "Install Docker Desktop from https://docker.com/products/docker-desktop"
        echo "Then re-run this script."
        exit 1
    elif [[ "$OS" == "alpine" ]]; then
        apk add --no-cache docker docker-compose
        rc-update add docker boot
        service docker start
    else
        curl -fsSL https://get.docker.com | sh
    fi
    echo "[ok] Docker installed"
fi

# ── Docker Compose (plugin) ────────────────────────────
if docker compose version &>/dev/null; then
    echo "[skip] Docker Compose already installed: $(docker compose version --short)"
else
    echo "[install] Docker Compose plugin..."
    case "$OS" in
        debian)  apt-get install -y docker-compose-plugin ;;
        fedora)  dnf install -y docker-compose-plugin ;;
        rhel)    yum install -y docker-compose-plugin ;;
        alpine)  apk add --no-cache docker-compose ;;
        macos)   echo "Docker Compose is included with Docker Desktop" ;;
        *)       echo "Could not install docker-compose-plugin automatically"; exit 1 ;;
    esac
    echo "[ok] Docker Compose installed"
fi

# ── just ────────────────────────────────────────────────
if command -v just &>/dev/null; then
    echo "[skip] just already installed: $(just --version)"
else
    echo "[install] just..."
    if [[ "$OS" == "macos" ]]; then
        brew install just
    else
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
    fi
    echo "[ok] just installed"
fi

# ── Docker group (non-root) ────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
    if ! groups | grep -q docker; then
        echo "[setup] Adding $USER to docker group..."
        sudo usermod -aG docker "$USER"
        echo "[ok] Added — log out and back in for it to take effect"
    fi
fi

# ── Verify ──────────────────────────────────────────────
echo ""
echo "=== Verification ==="
echo "Docker:          $(docker --version)"
echo "Docker Compose:  $(docker compose version)"
echo "just:            $(just --version)"
echo ""
echo "All dependencies installed. Run 'just new' to configure a runner."
