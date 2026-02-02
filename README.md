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

## Deployment

- Single Go binary; no embedded HTML/CSS/JS.

## Uninstallation

If installed via the install script:

```bash
curl -sL https://raw.githubusercontent.com/jasper-node/jaspermate-utils/refs/heads/main/scripts/install_to_linux.sh | sudo -E bash -s -- uninstall
```

## License

This project is open source.
