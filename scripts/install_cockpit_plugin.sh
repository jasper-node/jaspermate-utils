#!/bin/sh

# ==============================================================================
# install_cockpit_plugin.sh
#
# Installs or uninstalls the JasperMate Cockpit plugins (IO + SIM).
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
RAW_BASE="${BASE_URL:-https://raw.githubusercontent.com/${GITHUB_REPO}/refs/heads/${BRANCH}}"

# Plugin definitions
IO_NAME="jaspermate-io"
IO_DIR="/usr/share/cockpit/${IO_NAME}"
IO_SRC="cockpit_plugin/io"
IO_FILES="manifest.json index.html jaspermate-io.js jaspermate-io.css"

SIM_NAME="jaspermate-sim"
SIM_DIR="/usr/share/cockpit/${SIM_NAME}"
SIM_SRC="cockpit_plugin/cellular"
SIM_FILES="manifest.json index.html jaspermate-cellular.js jaspermate-cellular.css"

# Old plugin dirs to clean up
OLD_DIRS="/usr/share/cockpit/jaspermate /usr/share/cockpit/jaspermate-cellular"

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

install_plugin() {
  name="$1"
  dest="$2"
  src="$3"
  files="$4"

  info "Installing ${name}..."
  mkdir -p "${dest}"

  for file in ${files}; do
    info "  Downloading ${file}..."
    if ! curl -sL --fail "${RAW_BASE}/${src}/${file}" -o "${dest}/${file}"; then
      error "Failed to download ${src}/${file}"
      rm -rf "${dest}"
      return 1
    fi
  done

  info "${name} installed to ${dest}"
}

# --- Uninstall ---
case "${1:-}" in
  uninstall|--uninstall|-u)
    removed=0
    for dir in "${IO_DIR}" "${SIM_DIR}" ${OLD_DIRS}; do
      if [ -d "${dir}" ]; then
        info "Removing ${dir}..."
        rm -rf "${dir}"
        removed=1
      fi
    done
    if [ "${removed}" -eq 1 ]; then
      echo
      printf "${GREEN}JasperMate Cockpit plugins have been uninstalled.${NC}\n"
    else
      warn "No JasperMate Cockpit plugins found."
    fi
    exit 0
    ;;
esac

# --- Root check ---
if [ "$(id -u)" -ne 0 ]; then
  error "This installer must be run as root or with sudo."
  exit 1
fi

# --- Clean up old plugin dirs ---
for dir in ${OLD_DIRS}; do
  if [ -d "${dir}" ]; then
    info "Removing old plugin at ${dir}..."
    rm -rf "${dir}"
  fi
done

# --- Install both plugins ---
install_plugin "${IO_NAME}" "${IO_DIR}" "${IO_SRC}" "${IO_FILES}" || exit 1
install_plugin "${SIM_NAME}" "${SIM_DIR}" "${SIM_SRC}" "${SIM_FILES}" || exit 1

echo
printf "${GREEN}JasperMate Cockpit plugins installed successfully.${NC}\n"
echo
info "Open Cockpit in your browser to see JasperMate IO and JasperMate SIM."
