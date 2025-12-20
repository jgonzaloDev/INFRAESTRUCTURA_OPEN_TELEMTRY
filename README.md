# 🚀 Infraestructura Multimodulo - Spring Boot + React + Azure

Infraestructura como código (IaC) para desplegar una aplicación multimodulo con backend Spring Boot y frontend React en Azure usando Terraform y GitHub Actions.

## 📋 Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Gateway                       │
│                    (HTTPS Termination)                       │
└────────────┬────────────────────────┬───────────────────────┘
             │                        │
    ┌────────▼────────┐      ┌───────▼────────┐
    │  Spring Boot    │      │   React App    │
    │  (Backend API)  │◄─────┤   (Frontend)   │
    │   Java 17       │      │   Node 20.x    │
    └────────┬────────┘      └────────────────┘
             │
    ┌────────▼────────┐
    │  Azure SQL DB   │
    │   (Database)    │
    └─────────────────┘
```

### Componentes

- **Backend**: Spring Boot multimodulo (Customers + Orders)
- **Frontend**: React SPA
- **Base de datos**: Azure SQL Database
- **Red**: Virtual Network con subnets privadas
- **Seguridad**: Key Vault + Private Endpoints
- **Gateway**: Application Gateway con SSL
- **Monitoreo**: Application Insights + Log Analytics

## 📁 Estructura del Proyecto

```
infrastructure-multimodulo/
├── .github/
│   └── workflows/
│       ├── plan.yaml              # Terraform plan (PR preview)
│       ├── apply.yaml             # Terraform apply (deploy infra)
│       ├── deploy-backend.yml     # Deploy Spring Boot
│       ├── deploy-frontend.yml    # Deploy React
│       └── deploy-database.yml    # Deploy SQL migrations
├── infra/
│   └── main/
│       ├── main.tf                # Configuración Terraform
│       └── variables.tf           # Variables
├── database/
│   ├── migrations/
│   │   └── 001_create_tables.sql # Schema inicial
│   └── seeds/
│       └── 001_seed_data.sql     # Datos iniciales
└── README.md
```

## 🚀 Inicio Rápido

### Pre-requisitos

1. **Cuenta de Azure** con permisos de Contributor
2. **Repositorios de código**:
   - Backend: `jgonzaloDev/BACKEND_SPRING_MULTIMODULO`
   - Frontend: `jgonzaloDev/FRONT_REAC_DOJO`
3. **GitHub Personal Access Token** con permisos de repo
4. **Service Principal OIDC** configurado en Azure

### Paso 1: Configurar Identidad Federada (OIDC)

```bash
# 1. Crear App Registration en Azure AD
az ad app create --display-name "GitHub-Actions-OIDC"

# 2. Obtener el Application (client) ID
APP_ID=$(az ad app list --display-name "GitHub-Actions-OIDC" --query "[0].appId" -o tsv)

# 3. Crear Service Principal
az ad sp create --id $APP_ID

# 4. Obtener Object ID del Service Principal
OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)

# 5. Asignar rol Contributor
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/YOUR_SUBSCRIPTION_ID

# 6. Configurar credencial federada
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "GitHubActions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:TU_USUARIO/TU_REPO:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Paso 2: Configurar Secrets en GitHub

Ve a `Settings` > `Secrets and variables` > `Actions` y agrega:

#### Autenticación Azure
- `AZURE_CLIENT_ID` - Application (client) ID
- `AZURE_SUBSCRIPTION_ID` - ID de tu suscripción
- `AZURE_TENANT_ID` - Tenant ID

#### Configuración de Infraestructura
- `TF_VAR_LOCATION` - eastus2
- `TF_VAR_RESOURCE_GROUP_NAME` - rg-multimodulo-prod
- `TF_VAR_VNET_NAME` - vnet-multimodulo
- `TF_VAR_SQL_SERVER_NAME` - sql-multimodulo-prod
- `TF_VAR_DATABASE_NAME` - dbMultimodulo
- `TF_VAR_SQL_ADMIN_LOGIN` - sqladmin
- `TF_VAR_SQL_ADMIN_PASSWORD` - [contraseña fuerte]
- `TF_VAR_APP_SERVICE_PLAN_NAME` - asp-backend-multimodulo
- `TF_VAR_APP_SERVICE_PLAN_NAME_WEB` - asp-frontend-multimodulo
- `TF_VAR_APP_SERVICE_NAME` - app-backend-multimodulo
- `TF_VAR_APP_SERVICE_NAME_WEB` - app-frontend-multimodulo
- `TF_VAR_KEY_VAULT_NAME` - kv-multimodulo-prod
- `TF_VAR_STORAGE_ACCOUNT_NAME` - stmultimoduloprod
- `TF_VAR_ADMIN_USER_OBJECT_ID` - Tu Object ID en Azure AD
- `TF_VAR_GITHUB_PRINCIPAL_ID` - Object ID del Service Principal
- `TF_VAR_ENABLE_ELASTIC` - false (o true si usas Elasticsearch)

#### Certificado SSL (Opcional)
- `TF_VAR_CERT_DATA` - Certificado en base64
- `TF_VAR_CERT_PASSWORD` - Contraseña del certificado

#### GitHub
- `GH_PERSONAL_TOKEN` - Token para clonar repos privados

### Paso 3: Desplegar Infraestructura

```bash
# 1. Clonar este repositorio
git clone https://github.com/TU_USUARIO/infrastructure-multimodulo.git
cd infrastructure-multimodulo

# 2. Crear estructura de carpetas
mkdir -p infra/main database/migrations database/seeds .github/workflows

# 3. Push a GitHub
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

**En GitHub Actions:**

1. Ve a `Actions` > `Terraform Apply – MAIN Infra`
2. Click `Run workflow`
3. Espera ~10 minutos mientras se crea la infraestructura

### Paso 4: Desplegar Base de Datos

1. Ve a `Actions` > `Deploy Database Migrations`
2. Click `Run workflow`
3. Esto creará las tablas e insertará datos iniciales

### Paso 5: Desplegar Aplicaciones

**Backend:**
1. Ve a `Actions` > `Deploy Backend (Spring Boot App)`
2. Click `Run workflow`

**Frontend:**
1. Ve a `Actions` > `Deploy Frontend (React)`
2. Click `Run workflow`

### Paso 6: Verificar Despliegue

```bash
# Obtener URL del Application Gateway
az network public-ip show \
  --resource-group rg-multimodulo-prod \
  --name appgw-public-ip \
  --query ipAddress -o tsv

# Probar endpoints
curl https://[APP_GATEWAY_IP]/api/customers
curl https://[APP_GATEWAY_IP]/
```

## 🏗️ Workflows Disponibles

### 1. `plan.yaml` - Vista Previa de Cambios
- **Trigger**: Pull Request a `main`
- **Propósito**: Ver qué cambiará antes de aplicar
- **No modifica** recursos en Azure

### 2. `apply.yaml` - Desplegar Infraestructura
- **Trigger**: Manual (workflow_dispatch)
- **Propósito**: Crear/actualizar recursos en Azure
- **Duración**: ~10 minutos

### 3. `deploy-database.yml` - Migraciones SQL
- **Trigger**: Manual
- **Propósito**: Ejecutar scripts SQL en Azure SQL DB
- **Features**:
  - Validación de scripts
  - Backup automático (en main)
  - Seeds solo en develop
  - Firewall temporal

### 4. `deploy-backend.yml` - Deploy Spring Boot
- **Trigger**: Push a main/develop o manual
- **Propósito**: Compilar y desplegar backend Java
- **Process**:
  1. Clona repo de backend
  2. Maven build
  3. Deploy JAR a App Service
  4. Health check

### 5. `deploy-frontend.yml` - Deploy React
- **Trigger**: Push a main/develop o manual
- **Propósito**: Compilar y desplegar frontend
- **Process**:
  1. Clona repo de frontend
  2. npm build
  3. Deploy a App Service
  4. Verificación

## 🔐 Seguridad

### Private Endpoints
Todos los recursos tienen private endpoints:
- ✅ Backend App Service
- ✅ Frontend App Service
- ✅ SQL Server
- ✅ Key Vault
- ✅ Storage Account

### Key Vault
Las credenciales se almacenan en Key Vault:
- `db-database` - Nombre de la base de datos
- `db-username` - Usuario SQL
- `db-password` - Contraseña SQL

### Managed Identity
Los App Services usan Managed Identity para acceder a Key Vault sin credenciales hardcodeadas.

## 📊 Monitoreo

### Application Insights
- Telemetría de aplicaciones
- Performance monitoring
- Error tracking
- Custom metrics

### Log Analytics
- Logs centralizados
- Query con KQL
- Alertas personalizadas

## 🔄 CI/CD Flow

```mermaid
graph LR
    A[Código] --> B[GitHub Push]
    B --> C[GitHub Actions]
    C --> D{Workflow}
    D -->|Infra| E[Terraform Apply]
    D -->|Backend| F[Maven Build]
    D -->|Frontend| G[npm Build]
    D -->|DB| H[SQL Scripts]
    E --> I[Azure Resources]
    F --> J[App Service Backend]
    G --> K[App Service Frontend]
    H --> L[SQL Database]
```

## 🛠️ Comandos Útiles

### Terraform Local

```bash
cd infra/main

# Inicializar
terraform init

# Ver plan
terraform plan

# Aplicar cambios
terraform apply

# Destruir (¡CUIDADO!)
terraform destroy
```

### Azure CLI

```bash
# Ver recursos
az resource list \
  --resource-group rg-multimodulo-prod \
  --output table

# Ver logs del backend
az webapp log tail \
  --name app-backend-multimodulo \
  --resource-group rg-multimodulo-prod

# Conectar a SQL
sqlcmd -S sql-multimodulo-prod.database.windows.net \
  -d dbMultimodulo \
  -U sqladmin \
  -P [password]
```

## 🐛 Troubleshooting

### Error: "Backend storage doesn't exist"
El workflow crea el storage backend automáticamente. Verifica permisos del Service Principal.

### Error: "Name already exists"
Algunos recursos requieren nombres únicos globalmente. Agrega un sufijo único en los secrets.

### Error: "Unauthorized"
Verifica que el Service Principal tenga el rol "Contributor" en la suscripción.

### Backend no arranca
1. Verifica los logs: `az webapp log tail`
2. Revisa variables de entorno en App Service
3. Verifica conexión a SQL desde Key Vault

### Frontend muestra error de CORS
Verifica que `REACT_APP_API_URL` apunte al backend correcto.

## 📚 Recursos

- [Spring Boot Docs](https://spring.io/projects/spring-boot)
- [React Docs](https://react.dev/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure App Service](https://docs.microsoft.com/azure/app-service/)
- [GitHub Actions](https://docs.github.com/actions)

## 👥 Contribuir

1. Fork el proyecto
2. Crea una rama (`git checkout -b feature/nueva-feature`)
3. Commit tus cambios (`git commit -m 'Añadir nueva feature'`)
4. Push a la rama (`git push origin feature/nueva-feature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT.

---

**Hecho con ❤️ para proyectos multimodulo en Azure**
