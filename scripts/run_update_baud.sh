#!/bin/bash

# ==============================================================================
# run_update_baud.sh
#
# Convenience wrapper to run the correct update-baud binary for this machine
# without manually downloading the asset. It fetches the latest release from
# GitHub, downloads the matching update-baud binary for the current arch, and
# executes it with any passed arguments.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/run_update_baud.sh | bash -s -- -baud=115200
#
# Any flags after `--` are forwarded directly to update-baud.
# ==============================================================================

set -euo pipefail

GITHUB_REPO="jasper-node/jaspermate-utils"

error() {
  echo "[ERROR] $1" >&2
}

info() {
  echo "[INFO] $1"
}

get_arch_asset_suffix() {
  case "$(uname -m)" in
    x86_64) echo "linux-amd64" ;;
    aarch64) echo "linux-arm64" ;;
    *)
      error "Unsupported architecture: $(uname -m). Only x86_64 and aarch64 are supported."
      exit 1
      ;;
  esac
}

get_latest_update_baud_url() {
  local suffix="$1"

  info "Determining latest jaspermate-utils release..."
  local latest_version
  latest_version="$(curl -sL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)"
  if [ -z "${latest_version}" ]; then
    error "Could not determine latest release tag from GitHub API."
    exit 1
  fi

  # tag_name usually already includes leading "v"; keep as-is
  local asset_name="update-baud-${suffix}"
  local download_url="https://github.com/${GITHUB_REPO}/releases/download/${latest_version}/${asset_name}"

  echo "${download_url}"
}

main() {
  local suffix
  suffix="$(get_arch_asset_suffix)"

  local url
  url="$(get_latest_update_baud_url "${suffix}")"

  info "Downloading update-baud for $(uname -m) from:"
  info "  ${url}"

  local tmp_bin
  tmp_bin="$(mktemp)"

  if ! curl -sL --fail "${url}" -o "${tmp_bin}"; then
    error "Failed to download update-baud binary."
    rm -f "${tmp_bin}"
    exit 1
  fi

  if [ ! -s "${tmp_bin}" ]; then
    error "Downloaded update-baud binary is empty."
    rm -f "${tmp_bin}"
    exit 1
  fi

  chmod +x "${tmp_bin}"

  info "Running update-baud with forwarded arguments: $*"
  # Execute and forward all arguments. Do not trap errors so that its exit code
  # is propagated to the caller.
  "${tmp_bin}" "$@"

  rm -f "${tmp_bin}"
}

main "$@"

