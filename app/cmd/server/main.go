package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/platform-engineering/eks-go-golden-path/internal/config"
	"github.com/platform-engineering/eks-go-golden-path/internal/handlers"
	"github.com/platform-engineering/eks-go-golden-path/internal/middleware"
	"github.com/platform-engineering/eks-go-golden-path/internal/telemetry"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	cfg, err := config.Load()
	if err != nil {
		logger.Error("config_load_failed", "error", err)
		os.Exit(1)
	}

	ctx := context.Background()
	tel, err := telemetry.Setup(ctx, cfg)
	if err != nil {
		logger.Error("telemetry_setup_failed", "error", err)
		os.Exit(1)
	}
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := tel.Shutdown(shutdownCtx); err != nil {
			logger.Error("telemetry_shutdown_failed", "error", err)
		}
	}()

	svc := handlers.New(cfg)
	mux := http.NewServeMux()
	mux.HandleFunc("/", svc.Root)
	mux.HandleFunc("/healthz", svc.Healthz)
	mux.HandleFunc("/readyz", svc.Readyz)
	mux.HandleFunc("/work", svc.Work)
	mux.Handle("/metrics", tel.MetricsHandler)

	var handler http.Handler = mux
	handler = middleware.RequestID(handler)
	handler = middleware.Logging(logger, handler)
	handler = otelhttp.NewHandler(handler, cfg.ServiceName,
		otelhttp.WithFilter(func(r *http.Request) bool {
			// Avoid high-cardinality span names for probe endpoints if desired;
			// still instrument them but use low-cardinality route labels via otelhttp.
			return true
		}),
	)

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       cfg.ReadTimeout,
		WriteTimeout:      cfg.WriteTimeout,
		IdleTimeout:       cfg.IdleTimeout,
	}

	go func() {
		logger.Info("server_starting",
			"addr", cfg.HTTPAddr,
			"service", cfg.ServiceName,
			"version", cfg.ServiceVersion,
			"otlp_export", cfg.EnableOTLPExport,
		)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server_failed", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	sig := <-stop
	logger.Info("shutdown_signal", "signal", sig.String())

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful_shutdown_failed", "error", err)
		os.Exit(1)
	}
	logger.Info("server_stopped")
}
