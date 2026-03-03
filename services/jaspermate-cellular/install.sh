#!/bin/bash
# ==============================================================================
# install.sh - Install/uninstall jaspermate-cellular service
#
# Installs the Quectel EG25 QMI cellular data service on a Jaspermate edge PC.
#
# Usage (install):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/main/services/jaspermate-cellular/install.sh | sudo bash
#
# Usage (uninstall):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/main/services/jaspermate-cellular/install.sh | sudo bash -s -- uninstall
#
# ==============================================================================

set -euo pipefail

SERVICE_NAME="jaspermate-cellular"
GITHUB_RAW="https://raw.githubusercontent.com/jasper-node/jaspermate-utils/main/services/jaspermate-cellular"
CONFIG_DIR="/etc/jaspermate"
CONFIG_FILE="$CONFIG_DIR/config"

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'

info()  { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

# --- Uninstall ---
uninstall() {
    info "Uninstalling ${SERVICE_NAME}..."

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        info "Stopping service..."
        systemctl stop "$SERVICE_NAME"
    fi
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true

    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    rm -f "/usr/local/bin/${SERVICE_NAME}"
    systemctl daemon-reload

    if [ -f "$CONFIG_FILE" ]; then
        warn "Config preserved at $CONFIG_FILE (remove manually if desired)"
    fi

    echo -e "\n${C_GREEN}Uninstalled ${SERVICE_NAME}.${C_RESET}"
    exit 0
}

# --- Main ---
if [ "$(id -u)" -ne 0 ]; then
    error "Must run as root (sudo)."
    exit 1
fi

if [ "${1:-}" = "uninstall" ]; then
    uninstall
fi

# 1. Check for Quectel modem
if ! lsusb 2>/dev/null | grep -qi 'quectel\|2c7c'; then
    warn "No Quectel modem detected on USB. Service will wait for device at boot."
fi

# 2. Install dependency: libqmi-utils (provides qmicli)
if ! command -v qmicli &>/dev/null; then
    info "Installing libqmi-utils..."
    apt-get update -qq && apt-get install -y -qq libqmi-utils
fi

# 3. Install the script
info "Installing ${SERVICE_NAME} script..."
if [ -f "jaspermate-cellular" ]; then
    # Running from local repo checkout
    cp jaspermate-cellular "/usr/local/bin/${SERVICE_NAME}"
else
    # Running via curl from GitHub
    curl -sL "${GITHUB_RAW}/jaspermate-cellular" -o "/usr/local/bin/${SERVICE_NAME}"
fi
chmod +x "/usr/local/bin/${SERVICE_NAME}"

# 4. Install systemd service
info "Installing systemd service..."
if [ -f "jaspermate-cellular.service" ]; then
    cp jaspermate-cellular.service "/etc/systemd/system/${SERVICE_NAME}.service"
else
    curl -sL "${GITHUB_RAW}/jaspermate-cellular.service" -o "/etc/systemd/system/${SERVICE_NAME}.service"
fi

# 5. Install default config (don't overwrite existing)
mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_FILE" ]; then
    warn "Config already exists at $CONFIG_FILE - not overwriting."
    warn "New defaults saved to ${CONFIG_FILE}.new for reference."
    if [ -f "config.default" ]; then
        cp config.default "${CONFIG_FILE}.new"
    else
        curl -sL "${GITHUB_RAW}/config.default" -o "${CONFIG_FILE}.new"
    fi
else
    info "Installing default config to $CONFIG_FILE..."
    if [ -f "config.default" ]; then
        cp config.default "$CONFIG_FILE"
    else
        curl -sL "${GITHUB_RAW}/config.default" -o "$CONFIG_FILE"
    fi
fi

# 6. Enable and start
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
info "Service enabled. Starting..."
systemctl start "$SERVICE_NAME" && info "Service started." || warn "Service failed to start - check: journalctl -u $SERVICE_NAME"

echo
echo -e "${C_GREEN}Installed ${SERVICE_NAME} successfully.${C_RESET}"
echo
info "Edit config:   sudo nano $CONFIG_FILE"
info "Check status:  sudo ${SERVICE_NAME} status"
info "View logs:     journalctl -u ${SERVICE_NAME} -f"
echo
