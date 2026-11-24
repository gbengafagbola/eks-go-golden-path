package telemetry

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/platform-engineering/eks-go-golden-path/internal/config"
)

func TestSetupPrometheusHandler(t *testing.T) {
	ctx := context.Background()
	cfg := config.Config{
		ServiceName:      "platform-demo",
		ServiceVersion:   "test",
		EnableOTLPExport: false,
	}

	p, err := Setup(ctx, cfg)
	if err != nil {
		t.Fatalf("Setup: %v", err)
	}
	t.Cleanup(func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = p.Shutdown(shutdownCtx)
	})

	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rr := httptest.NewRecorder()
	p.MetricsHandler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	body, _ := io.ReadAll(rr.Body)
	if len(body) == 0 {
		t.Fatal("expected non-empty metrics body")
	}
}
