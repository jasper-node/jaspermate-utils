# JasperMate Utils

API-only backend for JasperMate IO. The frontend uses [Cockpit](https://github.com/jasper-node/jaspermate-io-cockpit-plugin).

## Features

- **JasperMate IO API**: REST API for JasperMate IO cards (discovery, read state, write DO/AO, reboot)
- **TCP server**: Optional TCP server on port 9081 for external automation clients

## Requirements

- **Go** (v1.19 or higher) for building
- Serial port access (`/dev/ttyS7`) and `dialout` group for JasperMate IO hardware

## Building

```bash
# Build Go binary only (no Node/CSS)
npm run build
# or
go build -o ./release/jm-utils-linux-amd64 main.go
```

Binaries are placed in `./release/`:
- `jm-utils-linux-amd64`
- `jm-utils-linux-arm64`

## Usage

The service listens on **port 9080** (HTTP API) and **port 9081** (TCP for automation).

```bash
./release/jm-utils-linux-amd64
# Or: go run main.go
```

- **API**: `http://localhost:9080`

### API Endpoints

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

## Install

Install or update the binary as a systemd service:

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_to_linux.sh | sudo -E bash -
```

Supports Linux amd64 and arm64. The service runs as `jm-utils` and listens on port 9080 (HTTP) and 9081 (TCP).

### One-off: update JasperMate IO baud rate

For boards still at factory default baud (e.g. 9600), you can use the `update-baud` helper script without worrying about architecture:

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/run_update_baud.sh \
  | bash -s -- -baud=115200
```

- **Detects arch automatically** (amd64 vs arm64)
- **Downloads the matching `update-baud` binary** from the latest GitHub release
- **Forwards any flags** after `--` directly to `update-baud`

Examples:

```bash
# Simplest: just change all default slaves to 115200 on /dev/ttyS7
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/run_update_baud.sh \
  | bash -s -- -baud=115200

# Explicit port, current baud, and slave IDs
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/run_update_baud.sh \
  | bash -s -- -port=/dev/ttyS7 -current=9600 -baud=115200 -slaves=1,2,3,4,5
```

## Cellular Data Service

The `jaspermate-cellular` service provides automatic cellular internet via the Quectel EG25 LTE modem using QMI. It connects at boot and works with any GSM provider.

### Install (standalone)

```bash
# From a repo checkout on the target device:
cd services/jaspermate-cellular && sudo bash install.sh

# Or remotely via curl:
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/main/services/jaspermate-cellular/install.sh | sudo bash
```

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

### Uninstall

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/main/services/jaspermate-cellular/install.sh | sudo bash -s -- uninstall
```

### Requirements

- Quectel EG25 modem (USB ID `2c7c:0125`) with `qmi_wwan_q` driver
- `libqmi-utils` package (installed automatically by `install.sh`)
- `ModemManager` service running (for modem power management)

## Deployment

- Single Go binary; no embedded HTML/CSS/JS.

## Uninstallation

If installed via the install script:

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_to_linux.sh | sudo -E bash -s -- uninstall
```

## License

This project is open source.
