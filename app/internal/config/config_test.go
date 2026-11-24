package config

import (
	"os"
	"testing"
	"time"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("MAX_WORK_DURATION", "")
	t.Setenv("MAX_WORK_CPU_MILLIS", "")
	// Clear potentially set vars from the environment for a clean default test.
	for _, k := range []string{
		"SERVICE_NAME", "HTTP_ADDR", "MAX_WORK_DURATION", "MAX_WORK_CPU_MILLIS",
	} {
		_ = os.Unsetenv(k)
	}

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() unexpected error: %v", err)
	}
	if cfg.ServiceName != "platform-demo" {
		t.Errorf("ServiceName = %q, want platform-demo", cfg.ServiceName)
	}
	if cfg.HTTPAddr != ":8080" {
		t.Errorf("HTTPAddr = %q, want :8080", cfg.HTTPAddr)
	}
	if cfg.MaxWorkDuration != 2*time.Second {
		t.Errorf("MaxWorkDuration = %v, want 2s", cfg.MaxWorkDuration)
	}
	if cfg.MaxWorkCPUMillis != 500 {
		t.Errorf("MaxWorkCPUMillis = %d, want 500", cfg.MaxWorkCPUMillis)
	}
}

func TestLoadRejectsExcessiveWorkBounds(t *testing.T) {
	t.Setenv("MAX_WORK_DURATION", "10s")
	_, err := Load()
	if err == nil {
		t.Fatal("expected error for excessive MAX_WORK_DURATION")
	}

	t.Setenv("MAX_WORK_DURATION", "1s")
	t.Setenv("MAX_WORK_CPU_MILLIS", "5000")
	_, err = Load()
	if err == nil {
		t.Fatal("expected error for excessive MAX_WORK_CPU_MILLIS")
	}
}

func TestLoadCustomValues(t *testing.T) {
	t.Setenv("SERVICE_NAME", "demo-svc")
	t.Setenv("HTTP_ADDR", ":9090")
	t.Setenv("MAX_WORK_DURATION", "1s")
	t.Setenv("MAX_WORK_CPU_MILLIS", "250")
	t.Setenv("OTEL_ENABLE_OTLP_EXPORT", "true")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() unexpected error: %v", err)
	}
	if cfg.ServiceName != "demo-svc" {
		t.Errorf("ServiceName = %q", cfg.ServiceName)
	}
	if cfg.HTTPAddr != ":9090" {
		t.Errorf("HTTPAddr = %q", cfg.HTTPAddr)
	}
	if !cfg.EnableOTLPExport {
		t.Error("EnableOTLPExport want true")
	}
}
