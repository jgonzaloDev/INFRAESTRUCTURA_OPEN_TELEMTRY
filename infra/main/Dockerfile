# ============================================================
# OTel Collector Custom Image
# Config embebida dentro de la imagen (sin File Share)
# ============================================================

FROM otel/opentelemetry-collector-contrib:latest

# Copiar la configuración dentro de la imagen
COPY otel-collector-config.yaml /etc/otelcol-contrib/otel-collector-config.yaml

# Exponer puertos
# 4317 → gRPC (Java backend)
# 4318 → HTTP/protobuf (React frontend)
EXPOSE 4317 4318

# Ejecutar el collector con la config embebida
CMD ["--config=/etc/otelcol-contrib/otel-collector-config.yaml"]
