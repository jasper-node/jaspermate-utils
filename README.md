# JasperMate Utils

API-only backend for Local IO. The frontend is provided by the **Cockpit** application (see `local-io/` package).

## Features

- **Local IO API**: REST API for Local IO cards (discovery, read state, write DO/AO, reboot)
- **TCP server**: Optional TCP server on port 9081 for external automation clients
- **Cockpit frontend**: Use the `local-io` Cockpit package for the web UI

## Requirements

- **Go** (v1.19 or higher) for building
- Serial port access (`/dev/ttyS7`) and `dialout` group for Local IO hardware

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
- **Cockpit**: Install the `local-io` package from `local-io/` and open it in Cockpit; it will call the API on `127.0.0.1:9080`.

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Service info `{"service":"local-io-api"}` |
| GET | `/api/local-io` | List cards and TCP connection status |
| POST | `/api/local-io/rediscover` | Rediscover Local IO cards |
| POST | `/api/local-io/{id}/write-do` | Write digital output |
| POST | `/api/local-io/{id}/write-ao` | Write analog output |
| POST | `/api/local-io/{id}/write-aotype` | Set AO type (4-20mA / 0-10V) |
| POST | `/api/local-io/{id}/reboot` | Reboot card |

When a TCP client is connected to port 9081, write operations from the HTTP API are disabled.

## File Structure

```
jasper-mate-utils/
├── main.go                 # API server (local-io only)
├── local-io/                # Cockpit package (frontend)
│   ├── manifest.json
│   ├── index.html
│   ├── local-io.js
│   └── local-io.css
├── src/server/
│   ├── config/             # Config (e.g. TCP serve externally)
│   ├── localio/            # Local IO manager, port, models
│   └── tcp/                # TCP server for automation
├── scripts/
│   ├── install_to_linux.sh
│   └── publish.js
├── go.mod
└── package.json
```

## Deployment

- Single Go binary; no embedded HTML/CSS/JS.
- Frontend: deploy the `local-io/` directory as a Cockpit package.
- For systemd install, use `scripts/install_to_linux.sh` (installs binary and jm-utils service).

## Uninstallation

If installed via the install script:

```bash
curl -sL https://raw.githubusercontent.com/controlx-io/jasper-mate-utils/refs/heads/main/scripts/install_to_linux.sh | sudo -E bash -s -- uninstall
```

## License

This project is open source.
