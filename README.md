# JasperMate Utils

Backend services and Cockpit plugin for JasperMate edge PCs. Includes IO card management, cellular connectivity, and a web UI via Cockpit.

## Components

| Component | Description |
|-----------|-------------|
| **JasperMate Utils** | Go backend — REST API (port 9080) + TCP server (port 9081) for IO card management |
| **Cockpit Plugin** | Web UI for JasperMate, served as a [Cockpit](https://cockpit-project.org/) plugin |
| **Cellular Service** | Systemd service for cellular internet via Quectel EG25 LTE modem (QMI) |

## Install

Each component is installed independently via curl. All support Linux amd64 and arm64.

### JasperMate Utils (backend)

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_utils.sh | sudo -E bash -
```

Installs the `jm-utils` binary as a systemd service on port 9080 (HTTP) and 9081 (TCP).

### Cockpit Plugin (web UI)

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cockpit_plugin.sh | sudo sh
```

Installs to `/usr/share/cockpit/jaspermate/`. Requires Cockpit to be installed on the system.

### Cellular Service

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cellular.sh | sudo bash
```

Installs the `jaspermate-cellular` systemd service for automatic cellular internet via QMI.

## Uninstall

```bash
# Utils
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_utils.sh | sudo -E bash -s -- uninstall

# Cockpit Plugin
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cockpit_plugin.sh | sudo sh -s -- uninstall

# Cellular
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_cellular.sh | sudo bash -s -- uninstall
```

## Building

```bash
npm run build    # Build amd64 + arm64 binaries to ./release/
npm run dev      # Run locally (go run main.go)
npm test         # Run all tests (go test ./...)
```

Binaries are placed in `./release/`:
- `jm-utils-linux-amd64`
- `jm-utils-linux-arm64`

## API Endpoints

The backend listens on **port 9080** (HTTP) and **port 9081** (TCP for automation).

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Service info `{"service":"jaspermate-io-api"}` |
| GET | `/api/jaspermate-io` | List cards and TCP connection status |
| POST | `/api/jaspermate-io/rediscover` | Rediscover JasperMate IO cards |
| POST | `/api/jaspermate-io/{id}/write-do` | Write digital output |
| POST | `/api/jaspermate-io/{id}/write-ao` | Write analog output |
| POST | `/api/jaspermate-io/{id}/write-aotype` | Set AO type (4-20mA / 0-10V) |
| POST | `/api/jaspermate-io/{id}/reboot` | Reboot card |

When a TCP client is connected to port 9081, write operations from the HTTP API are disabled.

## Cockpit Plugin

The Cockpit plugin (`cockpit-plugin/`) is a static web app — no build step required. It connects to the JasperMate Utils backend on `127.0.0.1:9080`.

Source files:
- `cockpit-plugin/manifest.json` — Cockpit plugin manifest
- `cockpit-plugin/index.html` — Main page
- `cockpit-plugin/jaspermate-io.js` — Application logic
- `cockpit-plugin/jaspermate-io.css` — Styles

## Cellular Data Service

The `jaspermate-cellular` service provides automatic cellular internet via the Quectel EG25 LTE modem using QMI. It connects at boot and works with any GSM provider.

### Configure

Edit `/etc/jaspermate/config`:

```ini
APN=telstra.internet   # carrier APN (leave empty for modem default)
PIN=                    # SIM PIN if required
ROUTE_METRIC=100        # 50=prefer cellular, 100=over WiFi, 700=fallback only
VOICE_ENABLE=no         # reserved for future intercom support
GPS_ENABLE=no           # reserved for future GPS support
```

### Usage

```bash
sudo jaspermate-cellular start    # connect
sudo jaspermate-cellular stop     # disconnect
sudo jaspermate-cellular status   # show signal, IP, route, session

sudo systemctl start jaspermate-cellular   # via systemd
sudo systemctl stop jaspermate-cellular
journalctl -u jaspermate-cellular -f       # live logs
```

### How it works

1. Waits for the QMI control device (`/dev/cdc-wdm0`) to appear
2. Ensures the modem is online and registered on the network
3. Starts a QMI WDS data session via `qmicli --device-open-qmi`
4. Configures `usb0` with IP/gateway/MTU from QMI (no dhclient — does not touch `/etc/resolv.conf`)
5. Adds a default route with the configured metric

### Requirements

- Quectel EG25 modem (USB ID `2c7c:0125`) with `qmi_wwan_q` driver
- `libqmi-utils` package (installed automatically by the installer)
- `ModemManager` service running (for modem power management)

## One-off: update JasperMate IO baud rate

For boards still at factory default baud (e.g. 9600):

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/run_update_baud.sh \
  | bash -s -- -baud=115200
```

## License

This project is open source.
