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
  subscription_id = var.AZURE_SUBSCRIPTION_ID
  tenant_id       = var.AZURE_TENANT_ID
}

provider "time" {}

# ============================================================
# 0.1 - GRUPO DE RECURSOS
# ============================================================

resource "azurerm_resource_group" "rg" {
  name     = var.RESOURCE_GROUP_NAME
  location = var.LOCATION
}

# ============================================================
# 0.2 - RED VIRTUAL
# ============================================================

resource "azurerm_virtual_network" "vnet" {
  name                = var.VNET_NAME
  location            = var.LOCATION
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

# Nueva subnet para Container Instances
resource "azurerm_subnet" "subnet_containers" {
  name                 = "subnet-containers"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.5.0/24"]

  delegation {
    name = "delegation-aci"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

# ============================================================
# APP SERVICE PLAN (BACKEND - Spring Boot)
# ============================================================

resource "azurerm_service_plan" "plan_backend" {
  name                = var.APP_SERVICE_PLAN_NAME
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B2" # Upgraded for Spring Boot
}

# ============================================================
# 1.0 - Backend App Service (Linux, Java Spring Boot)
# ============================================================

resource "azurerm_linux_web_app" "backend" {
  name                = var.APP_SERVICE_NAME
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan_backend.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    application_stack {
      java_version = "17"
      java_server  = "JAVA"
      java_server_version = "17"
    }
  }

  app_settings = {
    APP_ENV   = "production"
    DB_CONNECTION = "sqlsrv"
    DB_HOST       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
    DB_DATABASE = "@Microsoft.KeyVault(SecretUri=https://${var.KEY_VAULT_NAME}.vault.azure.net/secrets/db-database/)"
    DB_USERNAME = "@Microsoft.KeyVault(SecretUri=https://${var.KEY_VAULT_NAME}.vault.azure.net/secrets/db-username/)"
    DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=https://${var.KEY_VAULT_NAME}.vault.azure.net/secrets/db-password/)"
    
    # OpenTelemetry configuration
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://${azurerm_container_group.otel_collector.ip_address}:4317"
    OTEL_SERVICE_NAME           = "springboot-backend"
    OTEL_RESOURCE_ATTRIBUTES    = "service.namespace=dojo,deployment.environment=production"
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.app_insights.connection_string
  }
}

# VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "backend_vnet" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.subnet_integration.id
}

# ============================================================
# APP SERVICE PLAN (FRONTEND - React)
# ============================================================

resource "azurerm_service_plan" "plan_frontend" {
  name                = var.APP_SERVICE_PLAN_NAME_WEB
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# ============================================================
# Frontend App Service (Linux, Node.js para React)
# ============================================================

resource "azurerm_linux_web_app" "frontend" {
  name                = var.APP_SERVICE_NAME_WEB
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan_frontend.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    application_stack {
      node_version = "18-lts"
    }
  }

  app_settings = {
    REACT_APP_API_URL = "https://${azurerm_linux_web_app.backend.default_hostname}/api"
    
    # OpenTelemetry configuration for frontend
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://${azurerm_container_group.otel_collector.ip_address}:4317"
    OTEL_SERVICE_NAME           = "react-frontend"
    OTEL_RESOURCE_ATTRIBUTES    = "service.namespace=dojo,deployment.environment=production"
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.app_insights.connection_string
  }
}

# VNet Integration para frontend
resource "azurerm_app_service_virtual_network_swift_connection" "frontend_vnet" {
  app_service_id = azurerm_linux_web_app.frontend.id
  subnet_id      = azurerm_subnet.subnet_integration.id
}

# ============================================================
# 1.1 - KEY VAULT
# ============================================================

resource "azurerm_key_vault" "kv" {
  name                = var.KEY_VAULT_NAME
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = var.AZURE_TENANT_ID

  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
}

# ------------------------------------------------------------
# ROLES
# ------------------------------------------------------------

# GitHub Actions - Puede crear/modificar secrets en CI/CD
resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.GITHUB_PRINCIPAL_ID
}

# Tu usuario - Administración completa del Key Vault
resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.ADMIN_USER_OBJECT_ID
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
# Secretos Alineados
# ------------------------------------------------------------

resource "azurerm_key_vault_secret" "db_database" {
  name         = "db-database"
  value        = var.DATABASE_NAME
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = var.SQL_ADMIN_LOGIN
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.SQL_ADMIN_PASSWORD
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

# ============================================================
# 1.2 - SQL SERVER Y BASE DE DATOS
# ============================================================

resource "azurerm_mssql_server" "sql_server" {
  name                          = var.SQL_SERVER_NAME
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.LOCATION
  version                       = "12.0"
  administrator_login           = var.SQL_ADMIN_LOGIN
  administrator_login_password  = var.SQL_ADMIN_PASSWORD
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "database" {
  name      = var.DATABASE_NAME
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"
}

# ============================================================
# 1.3 - STORAGE ACCOUNT
# ============================================================

resource "azurerm_storage_account" "storage" {
  name                     = var.STORAGE_ACCOUNT_NAME
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.LOCATION
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = false
}

resource "azurerm_storage_container" "container" {
  name                  = "datos"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# ============================================================
# ETAPA 4: OBSERVABILIDAD
# ============================================================

# ------------------------------------------------------------
# 4.1 - LOG ANALYTICS WORKSPACE
# ------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "law" {
  name                = var.LOG_ANALYTICS_WORKSPACE_NAME
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ------------------------------------------------------------
# 4.2 - APPLICATION INSIGHTS
# ------------------------------------------------------------

resource "azurerm_application_insights" "app_insights" {
  name                = var.APPLICATION_INSIGHTS_NAME
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
}

# ------------------------------------------------------------
# 4.3 - NETWORK PROFILE FOR CONTAINER INSTANCES
# ------------------------------------------------------------

resource "azurerm_network_profile" "aci_profile" {
  name                = "aci-network-profile"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name

  container_network_interface {
    name = "aci-nic"

    ip_configuration {
      name      = "aci-ipconfig"
      subnet_id = azurerm_subnet.subnet_containers.id
    }
  }
}

# ------------------------------------------------------------
# 4.4 - OPENTELEMETRY COLLECTOR (Container Instance)
# ------------------------------------------------------------

resource "azurerm_container_group" "otel_collector" {
  name                = "otel-collector"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  network_profile_id  = azurerm_network_profile.aci_profile.id
  restart_policy      = "Always"

  container {
    name   = "otel-collector"
    image  = "otel/opentelemetry-collector-contrib:latest"
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 4317
      protocol = "TCP"
    }

    ports {
      port     = 4318
      protocol = "TCP"
    }

    ports {
      port     = 9200
      protocol = "TCP"
    }

    environment_variables = {
      APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.app_insights.connection_string
    }

    # Config file will be mounted via ConfigMap or injected
    # For simplicity, using inline config through environment
    commands = ["/otelcol-contrib", "--config=/etc/otel-collector-config.yaml"]
  }

  tags = {
    environment = "production"
    component   = "observability"
  }
}

# ------------------------------------------------------------
# 4.5 - ELASTICSEARCH (Container Instance) - OPCIONAL
# ------------------------------------------------------------

resource "azurerm_container_group" "elasticsearch" {
  count               = var.ENABLE_ELASTICSEARCH ? 1 : 0
  name                = "elasticsearch"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  network_profile_id  = azurerm_network_profile.aci_profile.id
  restart_policy      = "Always"

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
      "discovery.type"         = "single-node"
      "xpack.security.enabled" = "false"
      "ES_JAVA_OPTS"          = "-Xms2g -Xmx2g"
    }

    volume {
      name       = "elasticsearch-data"
      mount_path = "/usr/share/elasticsearch/data"
      empty_dir  = true
    }
  }

  tags = {
    environment = "production"
    component   = "observability"
  }
}

# ------------------------------------------------------------
# 4.6 - KIBANA (Container Instance) - OPCIONAL
# ------------------------------------------------------------

resource "azurerm_container_group" "kibana" {
  count               = var.ENABLE_ELASTICSEARCH ? 1 : 0
  name                = "kibana"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  network_profile_id  = azurerm_network_profile.aci_profile.id
  restart_policy      = "Always"

  container {
    name   = "kibana"
    image  = "docker.elastic.co/kibana/kibana:8.11.0"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 5601
      protocol = "TCP"
    }

    environment_variables = {
      ELASTICSEARCH_HOSTS = "http://${azurerm_container_group.elasticsearch[0].ip_address}:9200"
      SERVER_HOST         = "0.0.0.0"
    }
  }

  tags = {
    environment = "production"
    component   = "observability"
  }

  depends_on = [azurerm_container_group.elasticsearch]
}

# =================================================================================
# Public IP para Application Gateway
# ================================================================================

resource "azurerm_public_ip" "appgw_ip" {
  name                = "appgw-public-ip"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# =================================================================================
# Private Endpoints
# ================================================================================

resource "azurerm_private_endpoint" "backend_pe" {
  name                = "pe-backend"
  location            = var.LOCATION
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

resource "azurerm_private_endpoint" "frontend_pe" {
  name                = "pe-frontend"
  location            = var.LOCATION
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

resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sqlserver1"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "sqlserver1-connection"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_mssql_server.sql_server
  ]
}

resource "azurerm_private_endpoint" "keyvault_pe" {
  name                = "pe-keyvault"
  location            = var.LOCATION
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

resource "azurerm_private_endpoint" "blob_pe" {
  name                = "pe-blobstorage"
  location            = var.LOCATION
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
# Application Gateway
# ================================================================================

resource "azurerm_application_gateway" "appgw" {
  name                = "dojo-appgw"
  location            = var.LOCATION
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet_agw.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  frontend_port {
    name = "frontendPort443"
    port = 443
  }

  ssl_certificate {
    name     = "cert-app-dojo"
    data     = var.CERT_DATA
    password = var.CERT_PASSWORD
  }

  http_listener {
    name                           = "listener-https"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "frontendPort443"
    protocol                       = "Https"
    ssl_certificate_name           = "cert-app-dojo"
  }

  backend_address_pool {
    name         = "pool-backend"
    ip_addresses = [azurerm_private_endpoint.backend_pe.private_service_connection[0].private_ip_address]
  }

  backend_address_pool {
    name         = "pool-frontend"
    ip_addresses = [azurerm_private_endpoint.frontend_pe.private_service_connection[0].private_ip_address]
  }

  backend_http_settings {
    name                  = "setting-backend"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "probe-backend"
    host_name             = azurerm_linux_web_app.backend.default_hostname
    cookie_based_affinity = "Disabled"
  }

  backend_http_settings {
    name                  = "setting-frontend"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "probe-frontend"
    host_name             = azurerm_linux_web_app.frontend.default_hostname
    cookie_based_affinity = "Disabled"
  }

  probe {
    name                 = "probe-backend"
    protocol             = "Https"
    host                 = azurerm_linux_web_app.backend.default_hostname
    path                 = "/api/health"
    interval             = 30
    timeout              = 30
    unhealthy_threshold  = 3
    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                 = "probe-frontend"
    protocol             = "Https"
    host                 = azurerm_linux_web_app.frontend.default_hostname
    path                 = "/"
    interval             = 30
    timeout              = 30
    unhealthy_threshold  = 3
    match {
      status_code = ["200-399"]
    }
  }

  url_path_map {
    name                               = "url-path-map"
    default_backend_address_pool_name  = "pool-frontend"
    default_backend_http_settings_name = "setting-frontend"

    path_rule {
      name                       = "frontend-rule"
      paths                      = ["/web/*"]
      backend_address_pool_name  = "pool-frontend"
      backend_http_settings_name = "setting-frontend"
    }

    path_rule {
      name                       = "backend-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "pool-backend"
      backend_http_settings_name = "setting-backend"
    }
  }

  request_routing_rule {
    name               = "rule-path-routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "listener-https"
    url_path_map_name  = "url-path-map"
    priority           = 100
  }
}
