# ============================================================
# VARIABLES PRINCIPALES
# ============================================================

variable "AZURE_SUBSCRIPTION_ID" {
  description = "ID de la suscripción de Azure"
  type        = string
}

variable "AZURE_TENANT_ID" {
  description = "ID del tenant de Azure"
  type        = string
}

variable "LOCATION" {
  description = "Ubicación de los recursos (por ejemplo: eastus2)"
  type        = string
}

variable "RESOURCE_GROUP_NAME" {
  description = "Nombre del grupo de recursos"
  type        = string
}

# ============================================================
# VIRTUAL NETWORK Y SUBNETS
# ============================================================

variable "VNET_NAME" {
  description = "Nombre de la red virtual principal"
  type        = string
}

# ============================================================
# APP SERVICE PLANS Y WEB APPS
# ============================================================

variable "APP_SERVICE_PLAN_NAME" {
  description = "Nombre del App Service Plan para backend (Linux)"
  type        = string
}

variable "APP_SERVICE_PLAN_NAME_WEB" {
  description = "Nombre del App Service Plan para frontend (Linux)"
  type        = string
}

variable "APP_SERVICE_NAME" {
  description = "Nombre del App Service backend"
  type        = string
}

variable "APP_SERVICE_NAME_WEB" {
  description = "Nombre del App Service frontend"
  type        = string
}

# ============================================================
# CERTIFICADO PARA APPLICATION GATEWAY
# ============================================================

variable "CERT_DATA" {
  description = "Certificado SSL codificado en base64"
  type        = string
  sensitive   = true
}

variable "CERT_PASSWORD" {
  description = "Contraseña del certificado SSL"
  type        = string
  sensitive   = true
}

# ============================================================
# BASE DE DATOS SQL SERVER
# ============================================================

variable "SQL_SERVER_NAME" {
  description = "Nombre del servidor SQL"
  type        = string
}

variable "SQL_ADMIN_LOGIN" {
  description = "Usuario administrador del SQL Server"
  type        = string
}

variable "SQL_ADMIN_PASSWORD" {
  description = "Contraseña del usuario administrador del SQL Server"
  type        = string
  sensitive   = true
}

variable "DATABASE_NAME" {
  description = "Nombre de la base de datos"
  type        = string
}

# ============================================================
# KEY VAULT Y STORAGE
# ============================================================

variable "KEY_VAULT_NAME" {
  description = "Nombre del Key Vault principal"
  type        = string
}

variable "STORAGE_ACCOUNT_NAME" {
  description = "Nombre de la cuenta de almacenamiento (Blob)"
  type        = string
}

# ============================================================
# OBSERVABILIDAD - ETAPA 4
# ============================================================

variable "LOG_ANALYTICS_WORKSPACE_NAME" {
  description = "Nombre del Log Analytics Workspace"
  type        = string
  default     = "law-dojo-observability"
}

variable "APPLICATION_INSIGHTS_NAME" {
  description = "Nombre de Application Insights"
  type        = string
  default     = "appi-dojo-observability"
}

variable "ENABLE_ELASTICSEARCH" {
  description = "Habilitar Elasticsearch y Kibana (true/false)"
  type        = bool
  default     = false
}

# ============================================================
# IDENTIDAD FEDERADA (OIDC) DE GITHUB ACTIONS
# ============================================================

variable "AZURE_CLIENT_ID" {
  description = "Client ID de la identidad federada de GitHub (OIDC)"
  type        = string
}

# ============================================================
# KEY VAULT – ROLES (GitHub OIDC y tu usuario admin)
# ============================================================

variable "GITHUB_PRINCIPAL_ID" {
  description = "Object ID del Service Principal federado (OIDC) usado por GitHub Actions"
  type        = string
}

variable "ADMIN_USER_OBJECT_ID" {
  description = "Object ID de tu usuario personal en Azure AD (para rol Key Vault Admin)"
  type        = string
}
