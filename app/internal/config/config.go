package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds runtime configuration loaded from environment variables.
type Config struct {
	ServiceName      string
	ServiceVersion   string
	HTTPAddr         string
	ReadTimeout      time.Duration
	WriteTimeout     time.Duration
	IdleTimeout      time.Duration
	ShutdownTimeout  time.Duration
	MaxWorkDuration  time.Duration
	MaxWorkCPUMillis int
	OTLPEndpoint     string
	OTLPInsecure     bool
	EnableOTLPExport bool
	DemoBucket       string
	AWSRegion        string
}

// Load reads configuration from the environment with safe defaults for demos.
func Load() (Config, error) {
	cfg := Config{
		ServiceName:      getenv("SERVICE_NAME", "platform-demo"),
		ServiceVersion:   getenv("SERVICE_VERSION", "0.1.0"),
		HTTPAddr:         getenv("HTTP_ADDR", ":8080"),
		ReadTimeout:      durationEnv("HTTP_READ_TIMEOUT", 5*time.Second),
		WriteTimeout:     durationEnv("HTTP_WRITE_TIMEOUT", 15*time.Second),
		IdleTimeout:      durationEnv("HTTP_IDLE_TIMEOUT", 60*time.Second),
		ShutdownTimeout:  durationEnv("HTTP_SHUTDOWN_TIMEOUT", 10*time.Second),
		MaxWorkDuration:  durationEnv("MAX_WORK_DURATION", 2*time.Second),
		MaxWorkCPUMillis: intEnv("MAX_WORK_CPU_MILLIS", 500),
		OTLPEndpoint:     getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4318"),
		OTLPInsecure:     boolEnv("OTEL_EXPORTER_OTLP_INSECURE", true),
		EnableOTLPExport: boolEnv("OTEL_ENABLE_OTLP_EXPORT", false),
		DemoBucket:       getenv("DEMO_BUCKET", ""),
		AWSRegion:        getenv("AWS_REGION", "us-east-1"),
	}

	if cfg.MaxWorkDuration <= 0 {
		return Config{}, fmt.Errorf("MAX_WORK_DURATION must be positive")
	}
	if cfg.MaxWorkCPUMillis <= 0 {
		return Config{}, fmt.Errorf("MAX_WORK_CPU_MILLIS must be positive")
	}
	if cfg.MaxWorkDuration > 5*time.Second {
		return Config{}, fmt.Errorf("MAX_WORK_DURATION cannot exceed 5s (got %s)", cfg.MaxWorkDuration)
	}
	if cfg.MaxWorkCPUMillis > 2000 {
		return Config{}, fmt.Errorf("MAX_WORK_CPU_MILLIS cannot exceed 2000 (got %d)", cfg.MaxWorkCPUMillis)
	}

	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func durationEnv(key string, fallback time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return fallback
	}
	return d
}

func intEnv(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}

func boolEnv(key string, fallback bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return fallback
	}
	return b
}
