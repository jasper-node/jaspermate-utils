#!/bin/bash

# ==============================================================================
# install_cellular.sh
#
# Installs, updates, or uninstalls the JasperMate Cellular service.
# This is a thin wrapper that downloads and runs the full installer from
# services/jaspermate-cellular/install.sh in the same repo.
#
# Usage (Install):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cellular.sh | sudo bash
#
# Usage (Uninstall):
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cellular.sh | sudo bash -s -- uninstall
#
# ==============================================================================

set -e

GITHUB_REPO="jasper-node/jaspermate-utils"
BRANCH="main"
INSTALLER_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/refs/heads/${BRANCH}/services/jaspermate-cellular/install.sh"

# --- Root check ---
if [ "$(id -u)" -ne 0 ]; then
  printf "\033[0;31m[ERROR]\033[0m This installer must be run as root or with sudo.\n"
  exit 1
fi

# Download and execute the full installer, passing through any arguments
curl -sL --fail "${INSTALLER_URL}" | bash -s -- "$@"
