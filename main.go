package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"jaspermate-utils/src/server/config"
	"jaspermate-utils/src/server/localio"
	"jaspermate-utils/src/server/tcp"

	"github.com/gorilla/mux"
)

const version = "1.0.0"

type App struct {
	localioMgr *localio.Manager
	tcpServer  *tcp.TCPServer
}

func NewApp() *App {
	extMgr := localio.InitializeManager()
	tcpServer := tcp.NewTCPServer("9081", extMgr, version, config.GetConfig().ServeExternally)
	if err := tcpServer.Start(); err != nil {
		log.Printf("Warning: Failed to start TCP server: %v", err)
	}

	return &App{
		localioMgr: extMgr,
		tcpServer:  tcpServer,
	}
}

func (app *App) rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"service": "jaspermate-io-api"})
}

func (app *App) rediscoverLocalIOCardsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if app.localioMgr != nil {
		app.localioMgr.StopCycle()
	}

	app.localioMgr = localio.InitializeManager()
	cards := app.localioMgr.RefreshAll()
	json.NewEncoder(w).Encode(map[string]interface{}{"cards": cards})
}

func (app *App) getLocalIOCardsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	cards := app.localioMgr.GetAllCards()
	tcpConnected := app.tcpServer != nil && app.tcpServer.IsConnected()
	json.NewEncoder(w).Encode(map[string]interface{}{
		"cards":        cards,
		"tcpConnected": tcpConnected,
	})
}

func (app *App) localIOCardHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	cardID := vars["id"]

	if app.tcpServer != nil && app.tcpServer.IsConnected() {
		path := r.URL.Path
		if strings.HasSuffix(path, "/write-do") || strings.HasSuffix(path, "/write-ao") ||
			strings.HasSuffix(path, "/write-aotype") || strings.HasSuffix(path, "/reboot") {
			w.WriteHeader(http.StatusServiceUnavailable)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "TCP client is connected, frontend controls are disabled",
			})
			return
		}
	}

	_, ok := app.localioMgr.GetCard(cardID)
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "card not found"})
		return
	}

	path := r.URL.Path
	switch {
	case strings.HasSuffix(path, "/write-do"):
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			Index int  `json:"index"`
			State bool `json:"state"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "invalid body"})
			return
		}
		if err := app.localioMgr.QueueWriteDO(cardID, req.Index, req.State); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	case strings.HasSuffix(path, "/write-ao"):
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			Index int     `json:"index"`
			Value float32 `json:"value"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "invalid body"})
			return
		}
		if err := app.localioMgr.QueueWriteAO(cardID, req.Index, req.Value); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	case strings.HasSuffix(path, "/write-aotype"):
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			Index int    `json:"index"`
			Mode  string `json:"mode"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "invalid body"})
			return
		}
		if err := app.localioMgr.QueueWriteAOType(cardID, req.Index, req.Mode); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	case strings.HasSuffix(path, "/reboot"):
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		if err := app.localioMgr.RebootCard(cardID); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

func main() {
	os.Args[0] = "cm-utils"

	app := NewApp()

	r := mux.NewRouter()

	r.HandleFunc("/", app.rootHandler).Methods("GET")
	r.HandleFunc("/api/jaspermate-io", app.getLocalIOCardsHandler).Methods("GET")
	r.HandleFunc("/api/jaspermate-io/rediscover", app.rediscoverLocalIOCardsHandler).Methods("POST")
	r.HandleFunc("/api/jaspermate-io/{id}/write-do", app.localIOCardHandler).Methods("POST")
	r.HandleFunc("/api/jaspermate-io/{id}/write-ao", app.localIOCardHandler).Methods("POST")
	r.HandleFunc("/api/jaspermate-io/{id}/write-aotype", app.localIOCardHandler).Methods("POST")
	r.HandleFunc("/api/jaspermate-io/{id}/reboot", app.localIOCardHandler).Methods("POST")

	fmt.Println("JasperMate Utils (jaspermate-io API) starting on :9080")
	log.Fatal(http.ListenAndServe(":9080", r))
}
