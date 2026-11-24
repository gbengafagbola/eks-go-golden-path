package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/platform-engineering/eks-go-golden-path/internal/config"
)

func testConfig() config.Config {
	return config.Config{
		ServiceName:      "platform-demo",
		ServiceVersion:   "test",
		MaxWorkDuration:  1 * time.Second,
		MaxWorkCPUMillis: 100,
	}
}

func TestRoot(t *testing.T) {
	s := New(testConfig())
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rr := httptest.NewRecorder()
	s.Root(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["service"] != "platform-demo" {
		t.Errorf("service = %v", body["service"])
	}
}

func TestHealthz(t *testing.T) {
	s := New(testConfig())
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rr := httptest.NewRecorder()
	s.Healthz(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
}

func TestReadyz(t *testing.T) {
	s := New(testConfig())
	req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	rr := httptest.NewRecorder()
	s.Readyz(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}

	s.SetReady(false)
	rr = httptest.NewRecorder()
	s.Readyz(rr, req)
	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503", rr.Code)
	}
}

func TestWorkBoundsRequest(t *testing.T) {
	s := New(testConfig())
	// Request far beyond caps; handler must clamp.
	req := httptest.NewRequest(http.MethodGet, "/work?duration=30s&cpu_ms=9999", nil)
	rr := httptest.NewRecorder()
	s.Work(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if int(body["cpu_ms"].(float64)) != 100 {
		t.Errorf("cpu_ms = %v, want clamped 100", body["cpu_ms"])
	}
	if body["sleep"] != "1s" {
		t.Errorf("sleep = %v, want clamped 1s", body["sleep"])
	}
}

func TestRootNotFound(t *testing.T) {
	s := New(testConfig())
	req := httptest.NewRequest(http.MethodGet, "/unknown", nil)
	rr := httptest.NewRecorder()
	s.Root(rr, req)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("status = %d", rr.Code)
	}
}
