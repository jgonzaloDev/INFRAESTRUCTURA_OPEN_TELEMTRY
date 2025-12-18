# Infraestructura Etapa 4 - Observabilidad con OpenTelemetry

Este proyecto contiene la infraestructura como código (IaC) para desplegar una aplicación completa en Azure con observabilidad integrada usando OpenTelemetry, Application Insights y opcionalmente Elasticsearch/Kibana.

## 🏗️ Arquitectura

### Componentes principales:

1. **Frontend (React)** - App Service Linux con Node.js
2. **Backend (Spring Boot)** - App Service Linux con Java 17
3. **OpenTelemetry Collector** - Container Instance para recolección de trazas y logs
4. **Azure Monitor + Application Insights** - Observabilidad nativa de Azure
5. **Elasticsearch + Kibana** (Opcional) - Stack alternativo de observabilidad
6. **SQL Server** - Base de datos
7. **Key Vault** - Gestión de secretos
8. **Storage Account** - Almacenamiento de blobs
9. **Application Gateway** - Punto de entrada con SSL/TLS

## 📋 Requisitos previos

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Cuenta de Azure con permisos de Contributor
- Azure CLI instalado y autenticado
- Certificado SSL para Application Gateway (formato .pfx)

## 🚀 Despliegue

### 1. Configurar variables

Copia el archivo de ejemplo y completa los valores:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tus valores:

```hcl
subscription_id      = "tu-subscription-id"
tenant_id            = "tu-tenant-id"
location             = "eastus2"
resource_group_name  = "rg-dojo-etapa4"

# ... resto de variables
```

### 2. Inicializar Terraform

```bash
terraform init
```

### 3. Planificar el despliegue

```bash
terraform plan -out=tfplan
```

### 4. Aplicar la infraestructura

```bash
terraform apply tfplan
```

## 🔍 Componentes de Observabilidad

### Log Analytics Workspace
- Retención: 30 días
- SKU: PerGB2018
- Almacena todos los logs y métricas

### Application Insights
- Vinculado al Log Analytics Workspace
- Instrumentación automática para App Services
- Correlación de trazas distribuidas

### OpenTelemetry Collector
- **Puerto 4317**: gRPC receiver (trazas y métricas)
- **Puerto 4318**: HTTP receiver (logs)
- **Puerto 9200**: Logs HTTP endpoint

Configuración en `otel-collector-config.yaml`

### Variables de entorno en App Services

**Backend (Spring Boot):**
```
OTEL_EXPORTER_OTLP_ENDPOINT=http://<collector-ip>:4317
OTEL_SERVICE_NAME=springboot-backend
OTEL_RESOURCE_ATTRIBUTES=service.namespace=dojo,deployment.environment=production
APPLICATIONINSIGHTS_CONNECTION_STRING=<connection-string>
```

**Frontend (React):**
```
OTEL_EXPORTER_OTLP_ENDPOINT=http://<collector-ip>:4317
OTEL_SERVICE_NAME=react-frontend
OTEL_RESOURCE_ATTRIBUTES=service.namespace=dojo,deployment.environment=production
APPLICATIONINSIGHTS_CONNECTION_STRING=<connection-string>
```

## 📊 Instrumentación en código

### Spring Boot (Backend)

1. Agregar dependencias en `pom.xml`:

```xml
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
    <version>1.31.0</version>
</dependency>
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
    <version>1.31.0-alpha</version>
</dependency>
```

2. Configuración en `application.properties`:

```properties
otel.exporter.otlp.endpoint=${OTEL_EXPORTER_OTLP_ENDPOINT}
otel.service.name=${OTEL_SERVICE_NAME}
otel.resource.attributes=${OTEL_RESOURCE_ATTRIBUTES}
```

### React (Frontend)

1. Instalar paquetes:

```bash
npm install @opentelemetry/api @opentelemetry/sdk-trace-web @opentelemetry/instrumentation-fetch @opentelemetry/exporter-trace-otlp-http
```

2. Inicializar en tu aplicación:

```javascript
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';

const provider = new WebTracerProvider();
const exporter = new OTLPTraceExporter({
  url: process.env.REACT_APP_OTEL_ENDPOINT + '/v1/traces'
});

provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();
```

## 🔐 Seguridad

- **VNet Integration**: App Services integrados en VNet privada
- **Private Endpoints**: Conexiones privadas a SQL, Key Vault, Storage
- **Application Gateway**: Único punto de entrada público con SSL/TLS
- **Key Vault RBAC**: Control de acceso basado en roles
- **Managed Identities**: Autenticación sin secretos para App Services

## 📈 Monitoreo y Alertas

### Acceder a Application Insights

```bash
# Obtener el instrumentation key
terraform output application_insights_instrumentation_key

# Acceder al portal
https://portal.azure.com -> Application Insights -> <nombre>
```

### Consultas útiles en Log Analytics (KQL)

**Trazas de la aplicación:**
```kql
traces
| where cloud_RoleName in ("springboot-backend", "react-frontend")
| order by timestamp desc
| take 100
```

**Requests HTTP:**
```kql
requests
| where timestamp > ago(1h)
| summarize count() by resultCode, bin(timestamp, 5m)
| render timechart
```

**Errores y excepciones:**
```kql
exceptions
| where timestamp > ago(24h)
| summarize count() by type, outerMessage
```

## 🧪 Probar localmente con Docker

Para probar el stack de observabilidad localmente:

```bash
# Configurar variable de entorno
export APPLICATIONINSIGHTS_CONNECTION_STRING="tu-connection-string"

# Levantar servicios
docker-compose up -d

# Verificar logs
docker-compose logs -f otel-collector
```

Acceder a Kibana: http://localhost:5601

## 📦 Recursos desplegados

| Recurso | Cantidad | SKU/Tier |
|---------|----------|----------|
| Resource Group | 1 | N/A |
| Virtual Network | 1 | N/A |
| Subnets | 5 | N/A |
| App Service Plans | 2 | B1, B2 |
| App Services | 2 | Linux |
| SQL Server | 1 | Basic |
| Key Vault | 1 | Standard |
| Storage Account | 1 | Standard LRS |
| Log Analytics | 1 | PerGB2018 |
| Application Insights | 1 | N/A |
| Container Instances | 1-3 | 1-2 CPU |
| Application Gateway | 1 | Standard_v2 |
| Private Endpoints | 5 | N/A |

## 💰 Estimación de costos

**Configuración base (sin Elasticsearch):**
- App Services (B1 + B2): ~$55/mes
- SQL Database (Basic): ~$5/mes
- Application Gateway: ~$125/mes
- Container Instances: ~$30/mes
- Log Analytics: ~$2.30/GB ingestion
- Application Insights: Incluido en Log Analytics
- **Total aproximado: ~$220/mes + costos de ingesta de logs**

**Con Elasticsearch/Kibana:**
- + $120/mes adicional aproximado

## 🐛 Troubleshooting

### El Collector no recibe trazas

1. Verificar conectividad de red:
```bash
az container show --resource-group <rg> --name otel-collector --query ipAddress.ip
```

2. Verificar logs del collector:
```bash
az container logs --resource-group <rg> --name otel-collector
```

### App Service no puede conectar al Collector

Verificar VNet Integration:
```bash
az webapp vnet-integration list --resource-group <rg> --name <app-service>
```

### No aparecen datos en Application Insights

1. Verificar Connection String en App Settings
2. Revisar si la instrumentación está correcta en el código
3. Esperar 2-5 minutos (delay normal en ingesta)

## 🔄 Actualizar infraestructura

```bash
# Modificar archivos .tf según necesites
terraform plan
terraform apply
```

## 🗑️ Destruir infraestructura

```bash
terraform destroy
```

⚠️ **Advertencia:** Esto eliminará todos los recursos de forma permanente.

## 📚 Referencias

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Azure Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Spring Boot OpenTelemetry](https://opentelemetry.io/docs/instrumentation/java/spring-boot/)

## 📄 Licencia

Este proyecto es de uso educativo para el programa Dojo.
