#!/bin/bash
# ==============================================================================
# install_cellular.sh - Install/uninstall jaspermate-cellular service
#
# Installs the Quectel EG25 QMI cellular data service on a Jaspermate edge PC.
#
# Usage (install):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cellular.sh | sudo bash
#
# Usage (uninstall):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cellular.sh | sudo bash -s -- uninstall
#
# ==============================================================================

set -euo pipefail

SERVICE_NAME="jaspermate-cellular"
GITHUB_REPO="jasper-node/jaspermate-utils"
BRANCH="main"
RAW_BASE="${BASE_URL:-https://raw.githubusercontent.com/${GITHUB_REPO}/refs/heads/${BRANCH}}"
SVC_SRC="services/jaspermate-cellular"
CONFIG_DIR="/etc/jaspermate"
CONFIG_FILE="$CONFIG_DIR/config"

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'

info()  { printf "${C_GREEN}[INFO]${C_RESET} %s\n" "$1"; }
warn()  { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$1"; }
error() { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$1"; }

# Try local file first (repo checkout), fall back to remote download
install_file() {
    local filename="$1"
    local dest="$2"
    local local_path="${SVC_SRC}/${filename}"

    if [ -f "$local_path" ]; then
        cp "$local_path" "$dest"
    else
        curl -sL --fail "${RAW_BASE}/${SVC_SRC}/${filename}" -o "$dest" || {
            error "Failed to download ${filename}"
            return 1
        }
    fi
}

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

    echo
    printf "${C_GREEN}Uninstalled ${SERVICE_NAME}.${C_RESET}\n"
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

# Detect repo root if running from checkout
if [ -f "services/jaspermate-cellular/jaspermate-cellular" ]; then
    SVC_SRC="services/jaspermate-cellular"
elif [ -f "jaspermate-cellular" ]; then
    SVC_SRC="."
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
install_file "jaspermate-cellular" "/usr/local/bin/${SERVICE_NAME}"
chmod +x "/usr/local/bin/${SERVICE_NAME}"

# 4. Install systemd service
info "Installing systemd service..."
install_file "jaspermate-cellular.service" "/etc/systemd/system/${SERVICE_NAME}.service"

# 5. Install default config (don't overwrite existing)
mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_FILE" ]; then
    warn "Config already exists at $CONFIG_FILE - not overwriting."
    warn "New defaults saved to ${CONFIG_FILE}.new for reference."
    install_file "config.default" "${CONFIG_FILE}.new"
else
    info "Installing default config to $CONFIG_FILE..."
    install_file "config.default" "$CONFIG_FILE"
fi

# 6. Enable and start
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
info "Service enabled. Starting..."
systemctl start "$SERVICE_NAME" && info "Service started." || warn "Service failed to start - check: journalctl -u $SERVICE_NAME"

echo
printf "${C_GREEN}Installed ${SERVICE_NAME} successfully.${C_RESET}\n"
echo
info "Edit config:   sudo nano $CONFIG_FILE"
info "Check status:  sudo ${SERVICE_NAME} status"
info "View logs:     journalctl -u ${SERVICE_NAME} -f"
echo
