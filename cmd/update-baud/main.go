// update-baud is a one-off tool to write a baud rate to JasperMate IO cards and reboot them.
// Use when devices are still at factory default (9600) and you want to switch to e.g. 115200.
//
// Build (to dist/):
//   One-off command: mkdir -p dist && go build -o dist/update-baud ./cmd/update-baud
//   Or: make update-baud
//
// Usage:
//   go run ./cmd/update-baud -baud=115200
//   go run ./cmd/update-baud -port=/dev/ttyS7 -current=9600 -baud=115200 -slaves=1,2,3,4,5
//   dist/update-baud -baud=115200
//   or simply: dist/update-baud
//
// Port defaults to /dev/ttyS7 if not specified. Then power-cycle or wait for reboot.

package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/goburrow/modbus"
)

const (
	baudRateRegAddr  = 0x0020
	baudRateRegCount = 2
	rebootRegAddr    = 0x0010
	rebootRegValue   = 0xFF00
)

func main() {
	port := flag.String("port", "/dev/ttyS7", "Serial port (default /dev/ttyS7)")
	currentBaud := flag.Int("current", 9600, "Current baud rate (how devices are configured now)")
	targetBaud := flag.Int("baud", 115200, "Target baud rate to write to devices")
	slavesFlag := flag.String("slaves", "1,2,3,4,5", "Comma-separated slave IDs to try (e.g. 1,2,3,4,5)")
	flag.Parse()

	slaves, err := parseSlaves(*slavesFlag)
	if err != nil {
		log.Fatalf("slaves: %v", err)
	}

	if *targetBaud <= 0 {
		log.Fatalf("baud must be positive, got %d", *targetBaud)
	}

	handler := modbus.NewRTUClientHandler(*port)
	handler.BaudRate = *currentBaud
	handler.DataBits = 8
	handler.Parity = "N"
	handler.StopBits = 1
	handler.SlaveId = 1
	handler.Timeout = 500 * time.Millisecond

	if err := handler.Connect(); err != nil {
		log.Fatalf("connect %s at %d: %v", *port, *currentBaud, err)
	}
	defer handler.Close()

	client := modbus.NewClient(handler)
	delay := 5 * time.Millisecond

	updated := 0
	for _, sid := range slaves {
		handler.SlaveId = sid
		// Probe: read baud rate register (safe read)
		_, err := client.ReadHoldingRegisters(baudRateRegAddr, baudRateRegCount)
		if err != nil {
			log.Printf("slave %d: not found or no response (%v)", sid, err)
			time.Sleep(delay)
			continue
		}
		time.Sleep(delay)

		// Write target baud (32-bit big-endian)
		buf := make([]byte, 4)
		binary.BigEndian.PutUint32(buf, uint32(*targetBaud))
		_, err = client.WriteMultipleRegisters(baudRateRegAddr, baudRateRegCount, buf)
		if err != nil {
			log.Printf("slave %d: write baud failed: %v", sid, err)
			time.Sleep(delay)
			continue
		}
		time.Sleep(delay)

		// Reboot so new baud takes effect
		_, err = client.WriteSingleRegister(rebootRegAddr, rebootRegValue)
		if err != nil {
			log.Printf("slave %d: reboot failed: %v", sid, err)
		} else {
			log.Printf("slave %d: baud set to %d and reboot sent", sid, *targetBaud)
			updated++
		}
		time.Sleep(delay)
	}

	if updated == 0 {
		log.Fatalf("no cards updated (check port, current baud %d, and slave IDs)", *currentBaud)
	}
	fmt.Printf("Done. Updated %d card(s) to %d baud; they will use it after reboot.\n", updated, *targetBaud)
}

func parseSlaves(s string) ([]byte, error) {
	var out []byte
	for _, p := range strings.Split(s, ",") {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		n, err := strconv.Atoi(p)
		if err != nil || n < 1 || n > 255 {
			return nil, fmt.Errorf("invalid slave id %q", p)
		}
		out = append(out, byte(n))
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("no slave IDs")
	}
	return out, nil
}
