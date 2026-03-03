#!/bin/sh

# ==============================================================================
# install_cockpit_plugin.sh
#
# Installs or uninstalls the JasperMate Cockpit plugin.
#
# Usage (Install):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cockpit_plugin.sh | sudo sh
#
# Usage (Uninstall):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cockpit_plugin.sh | sudo sh -s -- uninstall
#
# ==============================================================================

set -e

GITHUB_REPO="jasper-node/jaspermate-utils"
BRANCH="main"
PLUGIN_NAME="jaspermate"
INSTALL_DIR="/usr/share/cockpit/${PLUGIN_NAME}"
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/refs/heads/${BRANCH}/cockpit-plugin"

FILES="manifest.json index.html jaspermate-io.js jaspermate-io.css"

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# --- Uninstall ---
case "${1:-}" in
  uninstall|--uninstall|-u)
    if [ -d "${INSTALL_DIR}" ]; then
      info "Uninstalling JasperMate Cockpit plugin..."
      rm -rf "${INSTALL_DIR}"
      info "Removed ${INSTALL_DIR}"
      echo
      printf "${GREEN}JasperMate Cockpit plugin has been uninstalled.${NC}\n"
    else
      warn "JasperMate Cockpit plugin is not installed."
    fi
    exit 0
    ;;
esac

# --- Root check ---
if [ "$(id -u)" -ne 0 ]; then
  error "This installer must be run as root or with sudo."
  exit 1
fi

# --- Install ---
info "Installing JasperMate Cockpit plugin..."

mkdir -p "${INSTALL_DIR}"

for file in ${FILES}; do
  info "Downloading ${file}..."
  if ! curl -sL --fail "${RAW_BASE}/${file}" -o "${INSTALL_DIR}/${file}"; then
    error "Failed to download ${file}"
    rm -rf "${INSTALL_DIR}"
    exit 1
  fi
done

echo
printf "${GREEN}JasperMate Cockpit plugin installed to %s${NC}\n" "${INSTALL_DIR}"
echo
info "Open Cockpit in your browser to see the JasperMate plugin."
