# 🔐 Guía de Configuración de GitHub Secrets

## ✅ Checklist Completo

### 🔵 Autenticación Azure (OIDC) - 3 secrets

| Secret Name | Descripción | Ejemplo | Dónde obtenerlo |
|-------------|-------------|---------|-----------------|
| `AZURE_CLIENT_ID` | Application (client) ID del Service Principal OIDC | `12345678-1234-1234-1234-123456789012` | Azure Portal > App registrations > [Tu app] > Application (client) ID |
| `AZURE_SUBSCRIPTION_ID` | ID de tu suscripción de Azure | `abcdef12-3456-7890-abcd-ef1234567890` | Azure Portal > Subscriptions > Subscription ID |
| `AZURE_TENANT_ID` | Tenant ID de Azure AD | `98765432-4321-4321-4321-098765432109` | Azure Portal > Azure Active Directory > Tenant ID |

### 🌍 Configuración General - 2 secrets

| Secret Name | Descripción | Valor Ejemplo |
|-------------|-------------|---------------|
| `TF_VAR_LOCATION` | Región de Azure | `eastus2` o `westus2` |
| `TF_VAR_RESOURCE_GROUP_NAME` | Nombre del grupo de recursos | `rg-multimodulo-prod` |

### 🌐 Networking - 1 secret

| Secret Name | Descripción | Valor Ejemplo |
|-------------|-------------|---------------|
| `TF_VAR_VNET_NAME` | Nombre de la red virtual | `vnet-multimodulo` |

### 🗄️ Base de Datos SQL - 4 secrets

| Secret Name | Descripción | Valor Ejemplo | Notas |
|-------------|-------------|---------------|-------|
| `TF_VAR_SQL_SERVER_NAME` | Nombre del SQL Server | `sql-multimodulo-prod` | Debe ser único globalmente |
| `TF_VAR_DATABASE_NAME` | Nombre de la base de datos | `dbMultimodulo` | |
| `TF_VAR_SQL_ADMIN_LOGIN` | Usuario administrador | `sqladmin` | No usar 'sa', 'admin', 'root' |
| `TF_VAR_SQL_ADMIN_PASSWORD` | Contraseña del admin | `M1Sup3rS3cr3t!2024` | Mínimo 12 caracteres, mayúsculas, minúsculas, números y símbolos |

### 🚀 App Services - 4 secrets

| Secret Name | Descripción | Valor Ejemplo | Notas |
|-------------|-------------|---------------|-------|
| `TF_VAR_APP_SERVICE_PLAN_NAME` | Plan para backend | `asp-backend-multimodulo` | |
| `TF_VAR_APP_SERVICE_PLAN_NAME_WEB` | Plan para frontend | `asp-frontend-multimodulo` | |
| `TF_VAR_APP_SERVICE_NAME` | Nombre del backend | `app-backend-multimodulo` | Debe ser único globalmente |
| `TF_VAR_APP_SERVICE_NAME_WEB` | Nombre del frontend | `app-frontend-multimodulo` | Debe ser único globalmente |

### 🔐 Key Vault - 3 secrets

| Secret Name | Descripción | Valor Ejemplo | Dónde obtenerlo |
|-------------|-------------|---------------|-----------------|
| `TF_VAR_KEY_VAULT_NAME` | Nombre del Key Vault | `kv-multimodulo-prod` | Máximo 24 caracteres, solo letras, números y guiones |
| `TF_VAR_ADMIN_USER_OBJECT_ID` | Tu Object ID | `11111111-2222-3333-4444-555555555555` | Azure Portal > Azure AD > Users > [Tu usuario] > Object ID |
| `TF_VAR_GITHUB_PRINCIPAL_ID` | Object ID del SP OIDC | `66666666-7777-8888-9999-000000000000` | Ver comando abajo |

### 💾 Storage - 1 secret

| Secret Name | Descripción | Valor Ejemplo | Notas |
|-------------|-------------|---------------|-------|
| `TF_VAR_STORAGE_ACCOUNT_NAME` | Nombre storage account | `stmultimoduloprod` | Solo minúsculas y números, máx 24 caracteres |

### 📜 Certificado SSL (Opcional) - 2 secrets

| Secret Name | Descripción | Valor Ejemplo | Notas |
|-------------|-------------|---------------|-------|
| `TF_VAR_CERT_DATA` | Certificado en base64 | `MIIKcAIBAzCCCi...` | Opcional, dejar vacío si no tienes |
| `TF_VAR_CERT_PASSWORD` | Contraseña del certificado | `CertP@ssw0rd!` | Opcional, dejar vacío si no tienes |

### 🔍 Features Opcionales - 2 secrets

| Secret Name | Descripción | Valor Ejemplo |
|-------------|-------------|---------------|
| `TF_VAR_ENABLE_ELASTIC` | Habilitar Elasticsearch | `false` o `true` |
| `TF_VAR_ENABLE_OTEL` | Habilitar OpenTelemetry Collector | `true` o `false` |

### 🐙 GitHub Access - 1 secret

| Secret Name | Descripción | Dónde obtenerlo |
|-------------|-------------|-----------------|
| `GH_PERSONAL_TOKEN` | Token para clonar repos | GitHub > Settings > Developer settings > Personal access tokens > Tokens (classic) > Generate new token |

---

## 📋 Total: 23 Secrets

- ✅ **Obligatorios**: 20 secrets
- ⭕ **Opcionales**: 3 secrets (certificado + features)

---

## 🛠️ Comandos Útiles

### Obtener tu Object ID (Admin User)

```bash
# Obtener tu Object ID
az ad signed-in-user show --query id -o tsv
```

### Obtener Object ID del Service Principal OIDC

```bash
# 1. Primero obtén el Application ID de tu app
APP_ID=$(az ad app list --display-name "GitHub-Actions-OIDC" --query "[0].appId" -o tsv)

# 2. Luego obtén el Object ID del Service Principal
az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv
```

### Generar contraseña segura para SQL

```bash
# Linux/macOS
openssl rand -base64 24 | tr -d "=+/" | cut -c1-20

# O manualmente: Mínimo 12 caracteres con:
# - Mayúsculas
# - Minúsculas
# - Números
# - Símbolos
```

### Convertir certificado a base64

```bash
# Si tienes un .pfx o .p12
base64 -i certificado.pfx -o cert.txt

# Luego copia el contenido de cert.txt al secret
```

---

## 📝 Cómo Agregar Secrets en GitHub

### Opción 1: Interfaz Web (Recomendado)

1. Ve a tu repositorio en GitHub
2. Click en **Settings** (Configuración)
3. En el menú lateral izquierdo, click en **Secrets and variables** > **Actions**
4. Click en el botón verde **New repository secret**
5. Ingresa el **Name** exacto (case-sensitive)
6. Pega el **Value**
7. Click en **Add secret**
8. Repite para cada secret

### Opción 2: GitHub CLI

```bash
# Instalar GitHub CLI
# https://cli.github.com/

# Autenticar
gh auth login

# Configurar secrets (ejemplo)
gh secret set AZURE_CLIENT_ID --body "12345678-1234-1234-1234-123456789012"
gh secret set AZURE_SUBSCRIPTION_ID --body "abcdef12-3456-7890-abcd-ef1234567890"
gh secret set AZURE_TENANT_ID --body "98765432-4321-4321-4321-098765432109"

# Configurar desde archivo
gh secret set TF_VAR_CERT_DATA < cert.txt
```

---

## ✅ Validación de Secrets

Después de configurar todos los secrets, verifica:

1. **Contar secrets**: Deberías tener al menos 20 secrets
2. **Revisar nombres**: Todos deben empezar con `AZURE_`, `TF_VAR_`, o `GH_`
3. **Probar workflow**: Ejecuta `plan.yaml` para verificar que todo funciona

---

## 🚨 Convenciones de Nombres

Para evitar errores, sigue estas reglas:

### SQL Server Name
- ✅ `sql-multimodulo-prod`
- ❌ `SQL_Multimodulo_Prod` (no mayúsculas)
- ❌ `sql.multimodulo.prod` (no puntos)

### Storage Account Name
- ✅ `stmultimoduloprod`
- ❌ `st-multimodulo-prod` (no guiones)
- ❌ `stMultimoduloProd` (solo minúsculas)
- ❌ `storage-multimodulo-prod-2024` (máx 24 caracteres)

### Key Vault Name
- ✅ `kv-multimodulo-prod`
- ✅ `kv-mm-prod`
- ❌ `KeyVault-Multimodulo-Production` (máx 24 caracteres)

### App Service Names
- ✅ `app-backend-multimodulo`
- ✅ `app-frontend-multimodulo`
- Deben ser únicos globalmente
- Sugerencia: Agrega tus iniciales o un número random

---

## 🔒 Mejores Prácticas

1. ✅ **Nunca** subas secrets al código
2. ✅ Usa contraseñas de al menos 16 caracteres
3. ✅ Rota las credenciales cada 90 días
4. ✅ Usa diferentes valores para dev/staging/prod
5. ✅ Limita acceso a los secrets solo a quien los necesita
6. ✅ Habilita auditoría de acceso

---

## 🆘 Problemas Comunes

### "Secret not found"
- Verifica que el nombre sea exactamente igual (case-sensitive)
- Asegúrate de estar en el repositorio correcto

### "Invalid value"
- Para Object IDs, deben ser UUIDs válidos
- Para nombres de recursos, revisa las convenciones arriba

### "Name already in use"
- Algunos recursos son globales (SQL Server, Storage, App Services)
- Agrega un sufijo único: tus iniciales + 3 números
- Ejemplo: `app-backend-multimodulo-jgd123`

---

## 📞 Obtener Ayuda

Si tienes problemas:

1. Revisa los logs de GitHub Actions
2. Verifica que todos los secrets estén configurados
3. Ejecuta el workflow `plan.yaml` para ver qué falta
4. Consulta la documentación de Azure

---

**¡Listo! Con todos estos secrets configurados, estarás listo para desplegar tu infraestructura. 🚀**
