package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"strconv"
	"time"

	"github.com/platform-engineering/eks-go-golden-path/internal/config"
)

// Server groups HTTP handlers for the demo service.
type Server struct {
	cfg     config.Config
	ready   bool
	started time.Time
}

// New creates a Server that is ready to serve after construction.
func New(cfg config.Config) *Server {
	return &Server{
		cfg:     cfg,
		ready:   true,
		started: time.Now().UTC(),
	}
}

// Root returns basic service identity.
func (s *Server) Root(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"service": s.cfg.ServiceName,
		"version": s.cfg.ServiceVersion,
		"status":  "ok",
		"uptime":  time.Since(s.started).String(),
	})
}

// Healthz is the liveness probe: process is alive.
func (s *Server) Healthz(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "alive"})
}

// Readyz is the readiness probe: process can accept traffic.
func (s *Server) Readyz(w http.ResponseWriter, r *http.Request) {
	if !s.ready {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

// SetReady toggles readiness (used in tests).
func (s *Server) SetReady(ready bool) {
	s.ready = ready
}

// Work runs a bounded CPU/sleep workload for controlled load testing.
// Query params:
//   - duration: sleep duration (capped by MaxWorkDuration)
//   - cpu_ms: busy-loop milliseconds (capped by MaxWorkCPUMillis)
func (s *Server) Work(w http.ResponseWriter, r *http.Request) {
	duration := parseDurationParam(r, "duration", 100*time.Millisecond, s.cfg.MaxWorkDuration)
	cpuMs := parseIntParam(r, "cpu_ms", 50, s.cfg.MaxWorkCPUMillis)

	start := time.Now()
	busyWork(time.Duration(cpuMs) * time.Millisecond)
	time.Sleep(duration)

	writeJSON(w, http.StatusOK, map[string]any{
		"status":     "completed",
		"cpu_ms":     cpuMs,
		"sleep":      duration.String(),
		"elapsed_ms": time.Since(start).Milliseconds(),
		"goroutines": runtime.NumGoroutine(),
		"bounded_by": map[string]any{
			"max_duration":   s.cfg.MaxWorkDuration.String(),
			"max_cpu_millis": s.cfg.MaxWorkCPUMillis,
		},
	})
}

func busyWork(d time.Duration) {
	deadline := time.Now().Add(d)
	x := 0
	for time.Now().Before(deadline) {
		x++
		if x%1000 == 0 {
			runtime.Gosched()
		}
	}
	_ = x
}

func parseDurationParam(r *http.Request, key string, def, max time.Duration) time.Duration {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return def
	}
	d, err := time.ParseDuration(raw)
	if err != nil || d < 0 {
		return def
	}
	if d > max {
		return max
	}
	return d
}

func parseIntParam(r *http.Request, key string, def, max int) int {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return def
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 0 {
		return def
	}
	if n > max {
		return max
	}
	return n
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(true)
	if err := enc.Encode(v); err != nil {
		fmt.Fprintf(w, `{"error":"encode_failed"}`)
	}
}
