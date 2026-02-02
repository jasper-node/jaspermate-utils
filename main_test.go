package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandlers(t *testing.T) {
	app := NewApp()

	t.Run("Root", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/", nil)
		rr := httptest.NewRecorder()
		app.rootHandler(rr, req)
		if rr.Code != http.StatusOK {
			t.Errorf("Root handler returned wrong status code: got %v want %v", rr.Code, http.StatusOK)
		}
		var out map[string]string
		if err := json.NewDecoder(rr.Body).Decode(&out); err != nil {
			t.Fatalf("Failed to decode response: %v", err)
		}
		if out["service"] != "jaspermate-io-api" {
			t.Errorf("Expected service jaspermate-io-api, got %s", out["service"])
		}
	})

	t.Run("JasperMate IO cards", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/jaspermate-io", nil)
		rr := httptest.NewRecorder()
		app.getLocalIOCardsHandler(rr, req)
		if rr.Code != http.StatusOK {
			t.Errorf("JasperMate IO handler returned wrong status code: got %v want %v", rr.Code, http.StatusOK)
		}
		var out struct {
			Cards        []interface{} `json:"cards"`
			TCPConnected bool          `json:"tcpConnected"`
		}
		if err := json.NewDecoder(rr.Body).Decode(&out); err != nil {
			t.Fatalf("Failed to decode response: %v", err)
		}
		// Cards may be empty if no hardware; we only check structure
		if out.Cards == nil {
			t.Error("Expected non-nil cards array")
		}
	})
}
