FROM golang:1.23.5-bookworm AS builder

WORKDIR /src

COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

LABEL org.opencontainers.image.title="platform-demo" \
      org.opencontainers.image.description="Secure observable Go microservice golden path demo" \
      org.opencontainers.image.source="https://github.com/platform-engineering/eks-go-golden-path"

WORKDIR /
COPY --from=builder /out/server /server

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
