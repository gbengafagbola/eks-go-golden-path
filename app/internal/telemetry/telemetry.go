package telemetry

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/platform-engineering/eks-go-golden-path/internal/config"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	otelprom "go.opentelemetry.io/otel/exporters/prometheus"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

// Providers holds OTel providers that must be shut down gracefully.
type Providers struct {
	TracerProvider *sdktrace.TracerProvider
	MeterProvider  *sdkmetric.MeterProvider
	MetricsHandler http.Handler
}

// Setup configures Prometheus scrape metrics always, and optional OTLP export.
func Setup(ctx context.Context, cfg config.Config) (*Providers, error) {
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(cfg.ServiceName),
			semconv.ServiceVersion(cfg.ServiceVersion),
			attribute.String("deployment.environment", "demo"),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("resource: %w", err)
	}

	registry := prometheus.NewRegistry()
	promExporter, err := otelprom.New(otelprom.WithRegisterer(registry))
	if err != nil {
		return nil, fmt.Errorf("prometheus exporter: %w", err)
	}

	metricOpts := []sdkmetric.Option{
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(promExporter),
	}

	var tracerProvider *sdktrace.TracerProvider

	if cfg.EnableOTLPExport {
		otlpMetricOpts := []otlpmetrichttp.Option{
			otlpmetrichttp.WithEndpoint(cfg.OTLPEndpoint),
		}
		traceOpts := []otlptracehttp.Option{
			otlptracehttp.WithEndpoint(cfg.OTLPEndpoint),
		}
		if cfg.OTLPInsecure {
			otlpMetricOpts = append(otlpMetricOpts, otlpmetrichttp.WithInsecure())
			traceOpts = append(traceOpts, otlptracehttp.WithInsecure())
		}

		otlpMetric, err := otlpmetrichttp.New(ctx, otlpMetricOpts...)
		if err != nil {
			return nil, fmt.Errorf("otlp metric exporter: %w", err)
		}
		metricOpts = append(metricOpts, sdkmetric.WithReader(
			sdkmetric.NewPeriodicReader(otlpMetric, sdkmetric.WithInterval(30*time.Second)),
		))

		otlpTrace, err := otlptracehttp.New(ctx, traceOpts...)
		if err != nil {
			return nil, fmt.Errorf("otlp trace exporter: %w", err)
		}
		tracerProvider = sdktrace.NewTracerProvider(
			sdktrace.WithBatcher(otlpTrace),
			sdktrace.WithResource(res),
			sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.1))),
		)
	} else {
		tracerProvider = sdktrace.NewTracerProvider(
			sdktrace.WithResource(res),
			sdktrace.WithSampler(sdktrace.AlwaysSample()),
		)
	}

	meterProvider := sdkmetric.NewMeterProvider(metricOpts...)

	otel.SetTracerProvider(tracerProvider)
	otel.SetMeterProvider(meterProvider)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	return &Providers{
		TracerProvider: tracerProvider,
		MeterProvider:  meterProvider,
		MetricsHandler: promhttp.HandlerFor(registry, promhttp.HandlerOpts{EnableOpenMetrics: true}),
	}, nil
}

// Shutdown flushes and closes providers.
func (p *Providers) Shutdown(ctx context.Context) error {
	var first error
	if p.TracerProvider != nil {
		if err := p.TracerProvider.Shutdown(ctx); err != nil && first == nil {
			first = err
		}
	}
	if p.MeterProvider != nil {
		if err := p.MeterProvider.Shutdown(ctx); err != nil && first == nil {
			first = err
		}
	}
	return first
}
