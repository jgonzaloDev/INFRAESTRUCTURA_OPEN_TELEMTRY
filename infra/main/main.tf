terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.34.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "time" {}

# ============================================================
# 0.1 - GRUPO DE RECURSOS
# ============================================================

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# ============================================================
# 0.2 - RED VIRTUAL
# ============================================================

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# -----------------------------
# 0.2.1 - SUBNETS
# -----------------------------

resource "azurerm_subnet" "subnet_agw" {
  name                 = "subnet-agw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet_appservices" {
  name                 = "subnet-appservices"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "subnet_integration" {
  name                 = "subnet-integration"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "subnet_pe" {
  name                 = "subnet-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

# ============================================================
# APP SERVICE PLAN (BACKEND - Spring Boot)
# ============================================================

resource "azurerm_service_plan" "plan_backend" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B2"
}

# ============================================================
# 1.0 - Backend App Service (Linux, Java 17 - Spring Boot)
# ============================================================

resource "azurerm_linux_web_app" "backend" {
  name                = var.app_service_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan_backend.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    
    application_stack {
      java_server         = "JAVA"
      java_server_version = "17"
      java_version        = "17"
    }

    # CORS para permitir que el frontend acceda al backend
    cors {
      allowed_origins = [
        "https://${var.app_service_name_web}.azurewebsites.net",
        "http://localhost:3000"
      ]
      support_credentials = true
    }
  }

  app_settings = {
    # Spring Boot Configuration
    "SPRING_PROFILES_ACTIVE" = "production"
    
    # Database Configuration (usando Key Vault)
    "SPRING_DATASOURCE_URL"      = "jdbc:sqlserver://${azurerm_mssql_server.sql_server.fully_qualified_domain_name}:1433;database=@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/db-database/);encrypt=true;trustServerCertificate=false;"
    "SPRING_DATASOURCE_USERNAME" = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/db-username/)"
    "SPRING_DATASOURCE_PASSWORD" = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/db-password/)"
    "SPRING_DATASOURCE_DRIVER_CLASS_NAME" = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
    
    # JPA/Hibernate Configuration
    "SPRING_JPA_HIBERNATE_DDL_AUTO" = "none"
    "SPRING_JPA_SHOW_SQL"           = "false"
    "SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT" = "org.hibernate.dialect.SQLServerDialect"
    
    # Elasticsearch Configuration
    "ELASTICSEARCH_ENABLED" = var.enable_elastic
    "ELASTICSEARCH_HOST"    = var.enable_elastic == "true" ? azurerm_container_group.elasticsearch[0].ip_address : ""
    "ELASTICSEARCH_PORT"    = "9200"
    
    # OpenTelemetry Configuration
    "OTEL_EXPORTER_OTLP_ENDPOINT" = var.enable_otel == "true" ? "http://${azurerm_container_group.otel_collector[0].ip_address}:4318" : ""
    "OTEL_SERVICE_NAME"           = "spring-boot-backend"
    "OTEL_TRACES_EXPORTER"        = "otlp"
    "OTEL_METRICS_EXPORTER"       = "otlp"
    
    # Application Insights
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    
    # Server Configuration
    "SERVER_PORT" = "8080"
  }
}

# VNet Integration para Backend
resource "azurerm_app_service_virtual_network_swift_connection" "backend_integration" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.subnet_integration.id
}

# ============================================================
# 1.1 - APP SERVICE PLAN (FRONTEND - React)
# ============================================================

resource "azurerm_service_plan" "plan_frontend" {
  name                = var.app_service_plan_name_web
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# ============================================================
# 1.2 - Frontend App Service (Linux, Node.js - React)
# ============================================================

resource "azurerm_linux_web_app" "frontend" {
  name                = var.app_service_name_web
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan_frontend.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false
    
    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    # React Environment Variables
    "REACT_APP_API_URL"     = "https://${var.app_service_name}.azurewebsites.net"
    "REACT_APP_ENVIRONMENT" = "production"
    
    # Build Configuration
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "20-lts"
  }
}

# ============================================================
# 1.3 - KEY VAULT
# ============================================================

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = var.tenant_id

  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
}

# ------------------------------------------------------------
# ROLES KEY VAULT
# ------------------------------------------------------------

# GitHub Actions - Puede crear/modificar secrets en CI/CD
resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.github_principal_id
}

# Tu usuario - Administración completa del Key Vault
resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.admin_user_object_id
}

# Backend App Service - Puede leer secrets en runtime
resource "azurerm_role_assignment" "backend_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}

# Espera propagación de permisos RBAC
resource "time_sleep" "wait_for_iam" {
  create_duration = "45s"
  depends_on = [
    azurerm_role_assignment.github_kv_secrets,
    azurerm_role_assignment.user_kv_admin,
    azurerm_role_assignment.backend_kv_secrets
  ]
}

# ------------------------------------------------------------
# Secretos en Key Vault
# ------------------------------------------------------------

resource "azurerm_key_vault_secret" "db_database" {
  name         = "db-database"
  value        = var.database_name
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

# ============================================================
# 1.4 - SQL SERVER Y BASE DE DATOS
# ============================================================

resource "azurerm_mssql_server" "sql_server" {
  name                          = var.sql_server_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "database" {
  name      = var.database_name
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"
  collation = "SQL_Latin1_General_CP1_CI_AS"
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# 1.5 - STORAGE ACCOUNT
# ============================================================

resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = false
  }
}

resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# ============================================================
# 1.6 - LOG ANALYTICS & APPLICATION INSIGHTS
# ============================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_group_name}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "main" {
  name                = "${var.resource_group_name}-appi"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
}

# ============================================================
# 1.7 - ELASTICSEARCH (Container Instance)
# ============================================================

# Subnet para Container Instances
resource "azurerm_subnet" "subnet_containers" {
  name                 = "subnet-containers"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.5.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

# Container Instance para Elasticsearch
resource "azurerm_container_group" "elasticsearch" {
  count               = var.enable_elastic == "true" ? 1 : 0
  name                = "elasticsearch-container"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  dns_name_label      = "${var.resource_group_name}-elasticsearch"

  container {
    name   = "elasticsearch"
    image  = "docker.elastic.co/elasticsearch/elasticsearch:8.11.0"
    cpu    = "2"
    memory = "4"

    ports {
      port     = 9200
      protocol = "TCP"
    }

    ports {
      port     = 9300
      protocol = "TCP"
    }

    environment_variables = {
      "discovery.type"           = "single-node"
      "xpack.security.enabled"   = "false"
      "ES_JAVA_OPTS"            = "-Xms2g -Xmx2g"
    }

    volume {
      name                 = "elasticsearch-data"
      mount_path           = "/usr/share/elasticsearch/data"
      storage_account_name = azurerm_storage_account.storage.name
      storage_account_key  = azurerm_storage_account.storage.primary_access_key
      share_name          = azurerm_storage_share.elasticsearch[0].name
    }
  }

  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.subnet_containers.id]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# Storage Share para datos de Elasticsearch
resource "azurerm_storage_share" "elasticsearch" {
  count                = var.enable_elastic == "true" ? 1 : 0
  name                 = "elasticsearch-data"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50
}

# 1. Crear File Share para la configuración del OTel Collector
resource "azurerm_storage_share" "otel_config" {
  count                = var.enable_otel == "true" ? 1 : 0
  name                 = "otel-config"
  storage_account_name = azurerm_storage_account.main.name

# ============================================================
# OTEL COLLECTOR - FILE SHARE Y CONFIGURACIÓN
# ============================================================

resource "azurerm_storage_share" "otel_config" {
  count                = var.enable_otel == "true" ? 1 : 0
  name                 = "otel-config"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 1
}

resource "azurerm_storage_share_file" "otel_config_yaml" {
  count            = var.enable_otel == "true" ? 1 : 0
  name             = "otel-collector-config.yaml"
  storage_share_id = azurerm_storage_share.otel_config[0].id
  source           = "${path.module}/otel-collector-config.yaml"
}

# ============================================================
# OTEL COLLECTOR - CONTAINER INSTANCE
# ============================================================

resource "azurerm_container_group" "otel_collector" {
  count               = var.enable_otel == "true" ? 1 : 0
  name                = "otel-collector-container"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"

  container {
    name   = "otel-collector"
    image  = "otel/opentelemetry-collector-contrib:latest"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 4317
      protocol = "TCP"
    }

    ports {
      port     = 4318
      protocol = "TCP"
    }

    ports {
      port     = 8200
      protocol = "TCP"
    }

    environment_variables = {
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    }

    volume {
      name                 = "otel-config"
      mount_path           = "/etc/otelcol-contrib"
      read_only            = true
      storage_account_name = azurerm_storage_account.storage.name
      storage_account_key  = azurerm_storage_account.storage.primary_access_key
      share_name           = azurerm_storage_share.otel_config[0].name
    }

    commands = [
      "/otelcol-contrib",
      "--config=/etc/otelcol-contrib/otel-collector-config.yaml"
    ]
  }

  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.subnet_containers.id]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    azurerm_storage_share_file.otel_config_yaml
  ]
}

      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    }

    # Montar el archivo de configuración desde Azure File Share
    volume {
      name                 = "otel-config"
      mount_path           = "/etc/otelcol-contrib"
      read_only            = true
      storage_account_name = azurerm_storage_account.main.name
      storage_account_key  = azurerm_storage_account.main.primary_access_key
      share_name           = azurerm_storage_share.otel_config[0].name
    }

    # Comando para usar la configuración montada
    commands = [
      "/otelcol-contrib",
      "--config=/etc/otelcol-contrib/otel-collector-config.yaml"
    ]
  }

  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.subnet_containers.id]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }

  # Asegurar que el archivo de config esté subido antes de crear el container
  depends_on = [
    azurerm_storage_share_file.otel_config_yaml
  ]
}

# =================================================================================
# Private Endpoints
# ================================================================================

# Private Endpoint para Backend
resource "azurerm_private_endpoint" "backend_pe" {
  name                = "pe-backend"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "backend-connection"
    private_connection_resource_id = azurerm_linux_web_app.backend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_linux_web_app.backend
  ]
}

# Private Endpoint para Frontend
resource "azurerm_private_endpoint" "frontend_pe" {
  name                = "pe-frontend"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "frontend-connection"
    private_connection_resource_id = azurerm_linux_web_app.frontend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_linux_web_app.frontend
  ]
}

# Private Endpoint para SQL Server
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sqlserver"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "sqlserver-connection"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_mssql_server.sql_server
  ]
}

# Private Endpoint para Key Vault
resource "azurerm_private_endpoint" "keyvault_pe" {
  name                = "pe-keyvault"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "keyvault-connection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_key_vault.kv
  ]
}

# Private Endpoint para Storage Account
resource "azurerm_private_endpoint" "blob_pe" {
  name                = "pe-blobstorage"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "blob-connection"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_storage_account.storage
  ]
}
# =================================================================================
# OUTPUTS
# =================================================================================

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "backend_url" {
  value = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "frontend_url" {
  value = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "sql_server_fqdn" {
  value     = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  sensitive = true
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "application_insights_key" {
  value     = azurerm_application_insights.main.instrumentation_key
  sensitive = true
}
