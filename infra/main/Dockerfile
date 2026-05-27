# ============================================================
# OTel Collector Custom Image
# Config embebida dentro de la imagen (sin File Share)
# ============================================================
FROM otel/opentelemetry-collector-contrib:latest

# Copiar la configuración dentro de la imagen
COPY otel-collector-config.yaml /etc/otelcol-contrib/config.yaml

# Exponer puertos
# 4317 → gRPC
# 4318 → HTTP/protobuf
EXPOSE 4317 4318