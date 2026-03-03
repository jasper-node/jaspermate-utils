# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JasperMate Utils is the backend + Cockpit plugin for JasperMate edge PCs. The Go backend manages IO cards via Modbus RTU over RS485 serial, exposing a REST API on port 9080 and a TCP server on port 9081. The Cockpit plugin (`cockpit-plugin/`) provides the web UI. A separate systemd service handles cellular connectivity.

## Build & Development Commands

```bash
npm run dev              # Run locally (go run main.go)
npm run build            # Build amd64 + arm64 binaries to ./release/
npm test                 # Run all tests (go test ./...)
go test ./src/server/localio/...  # Run tests for a single package
go test -v -run TestName ./...    # Run a single test by name
make update-baud         # Build the update-baud CLI tool to dist/
```

## Architecture

### Core Flow

`main.go` → HTTP API (`gorilla/mux`) routes to `localio.Manager` for card operations, and starts a `tcp.Server` for automation clients.

### Key Packages

- **`src/server/localio/`** — Core IO card management. The `Manager` runs a background read-write cycle: it reads all cards sequentially, interleaving queued write operations after each card read to minimize write latency. Writes are batched by (cardID, registerType) and only sent if the value differs from cached state.
- **`src/server/tcp/`** — Single-client TCP server. Sends periodic card updates (500ms) and immediate updates on DI/AI state changes via callback. When the TCP client disconnects, all outputs are driven to safe state (DO off, AO to 0V/4mA). While a TCP client is connected, HTTP write operations are blocked.
- **`src/server/config/`** — YAML-based singleton config (`/var/lib/cm-utils/config.yaml` in production, `./tmp/config.yaml` locally). Thread-safe with `sync.Once` + `sync.RWMutex`.
- **`cmd/update-baud/`** — One-off CLI tool for changing card baud rates at factory defaults.

### Serial/Modbus Details

- Default serial port: `/dev/ttyS7`, auto-discovers slave IDs 1-5
- Modbus RTU: 115200 baud, 8N1, 200ms timeout, 2ms inter-operation delay for RS485 stability
- Card models (IO0404, IO0440, IO4040, IO8000, IO0080) define DI/DO/AI/AO channel counts
- Model is auto-detected by probing card capabilities

### Concurrency Patterns

- `Manager` uses `sync.Mutex` for card state and write queue
- Config uses `sync.RWMutex` for concurrent reads
- State change callbacks drive TCP push updates (no polling)
- Write queue is drained interleaved with reads to prevent write starvation

### Testing

Tests use mock implementations of `modbus.Client` (see `mock_test.go`). Config tests use temp directories with environment variable isolation. No real serial hardware needed for tests.

## Cellular Data Service (`services/jaspermate-cellular/`)

Systemd service that provides cellular internet via the Quectel EG25 LTE modem. Uses QMI protocol directly (bypasses NetworkManager for data) because the `qmi_wwan_q` driver is incompatible with ModemManager's Quectel plugin for the `cdc-wdm0` QMI port.

### Files

- **`jaspermate-cellular`** — Bash script: `start` / `stop` / `status`. Calls `qmicli -d /dev/cdc-wdm0 --device-open-qmi` for WDS session management, then configures `usb0` with static IP from QMI (no dhclient — avoids clobbering `/etc/resolv.conf`).
- **`jaspermate-cellular.service`** — Systemd oneshot unit. Runs after `ModemManager.service`, before `jaspernode.service`.
- **`config.default`** — Default config template, installed to `/etc/jaspermate/config`.
- **`install.sh`** — Installer: works from local checkout or via `curl` from GitHub raw. Installs `libqmi-utils` if missing.

### Key technical details

- **Driver**: `qmi_wwan_q` (Quectel custom) — standard `qmicli` needs `--device-open-qmi` flag to force QMI mode
- **Interfaces**: `cdc-wdm0` (QMI control), `usb0` (network data), `ttyUSB2` (AT primary), `ttyUSB1` (GPS)
- **IP config**: Retrieved via `qmicli --wds-get-current-settings` and applied with `ip addr add` — never touches resolv.conf
- **Session state**: Saved in `/run/jaspermate/cellular.state` (PDH + CID for clean disconnect)
- **Route metric**: Configurable in `/etc/jaspermate/config` (`ROUTE_METRIC`). WiFi default is 600.

### Testing on hardware

```bash
cd services/jaspermate-cellular && sudo bash install.sh   # install from repo
sudo jaspermate-cellular status                            # check everything
sudo jaspermate-cellular stop                              # stop without affecting DNS
sudo jaspermate-cellular start                             # reconnect
journalctl -u jaspermate-cellular                          # check boot logs
```
