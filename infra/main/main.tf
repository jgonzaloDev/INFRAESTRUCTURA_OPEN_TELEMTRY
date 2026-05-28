# ============================================================
# INFRAESTRUCTURA MULTIMODULO - ORDEN OPTIMIZADO DE DESPLIEGUE
# ============================================================

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
# FASE 1: FUNDACIÓN - Recursos base sin dependencias
# ============================================================

# 1.1 - GRUPO DE RECURSOS
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 1.2 - LOG ANALYTICS WORKSPACE
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_group_name}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  depends_on = [azurerm_resource_group.rg]
}

# 1.3 - APPLICATION INSIGHTS
resource "azurerm_application_insights" "main" {
  name                = "${var.resource_group_name}-appi"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  depends_on = [azurerm_log_analytics_workspace.main]
}

# ============================================================
# FASE 2: NETWORKING
# ============================================================

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "subnet_agw" {
  name                 = "subnet-agw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [azurerm_virtual_network.vnet]
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

  depends_on = [azurerm_virtual_network.vnet]
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

  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "subnet_pe" {
  name                 = "subnet-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]

  depends_on = [azurerm_virtual_network.vnet]
}

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

  depends_on = [azurerm_virtual_network.vnet]
}

# ============================================================
# FASE 3: STORAGE
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

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.storage]
}

resource "azurerm_storage_share" "elasticsearch" {
  count                = var.enable_elastic == "true" ? 1 : 0
  name                 = "elasticsearch-data"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50

  depends_on = [azurerm_storage_account.storage]
}

# ============================================================
# FASE 4: BASES DE DATOS
# ============================================================

resource "azurerm_mssql_server" "sql_server" {
  name                          = var.sql_server_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = false

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"

  depends_on = [azurerm_mssql_server.sql_server]
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

  depends_on = [azurerm_mssql_server.sql_server]
}

# ============================================================
# FASE 5: KEY VAULT
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

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.github_principal_id

  depends_on = [azurerm_key_vault.kv]
}

resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.admin_user_object_id

  depends_on = [azurerm_key_vault.kv]
}

resource "time_sleep" "wait_for_iam" {
  create_duration = "45s"

  depends_on = [
    azurerm_role_assignment.github_kv_secrets,
    azurerm_role_assignment.user_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_database" {
  name         = "db-database"
  value        = var.database_name
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [value]
  }

  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [value]
  }

  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [value]
  }

  depends_on = [time_sleep.wait_for_iam]
}

# ============================================================
# FASE 5.5: AZURE CONTAINER REGISTRY (ACR)
# ============================================================

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Purpose     = "OTel Collector Custom Image"
  }

  depends_on = [azurerm_resource_group.rg]
}

# ============================================================
# FASE 6: CONTAINER INSTANCES
# ============================================================

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
      "ES_JAVA_OPTS"             = "-Xms2g -Xmx2g"
      "action.auto_create_index" = "otel-logs-*,otel-traces-*,otel-metrics-*"
    }

    volume {
      name                 = "elasticsearch-data"
      mount_path           = "/usr/share/elasticsearch/data"
      storage_account_name = azurerm_storage_account.storage.name
      storage_account_key  = azurerm_storage_account.storage.primary_access_key
      share_name           = azurerm_storage_share.elasticsearch[0].name
    }
  }

  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.subnet_containers.id]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    azurerm_subnet.subnet_containers,
    azurerm_storage_share.elasticsearch
  ]
}

resource "azurerm_container_group" "kibana" {
  count               = var.enable_elastic == "true" ? 1 : 0
  name                = "kibana-container"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  dns_name_label      = "${var.resource_group_name}-kibana"

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
      "ELASTICSEARCH_HOSTS"    = "http://${azurerm_container_group.elasticsearch[0].ip_address}:9200"
      "SERVER_NAME"            = "kibana"
      "SERVER_HOST"            = "0.0.0.0"
      "ELASTICSEARCH_USERNAME" = ""
      "ELASTICSEARCH_PASSWORD" = ""
      "XPACK_SECURITY_ENABLED" = "false"
    }
  }

  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.subnet_containers.id]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }

  depends_on = [azurerm_container_group.elasticsearch]
}

# OPENTELEMETRY COLLECTOR — usa imagen custom desde ACR
resource "azurerm_container_group" "otel_collector" {
  count               = var.enable_otel == "true" ? 1 : 0
  name                = "otel-collector-container"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"

  image_registry_credential {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }

  container {
    name   = "otel-collector"
    image  = "${azurerm_container_registry.acr.login_server}/otel-collector-custom:latest"
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

    environment_variables = {
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
      "ELASTICSEARCH_HOST"                    = var.enable_elastic == "true" ? azurerm_container_group.elasticsearch[0].ip_address : ""
    }
  }

  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.subnet_containers.id]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Purpose     = "OTel Collector - ACR Custom Image"
  }

  depends_on = [
    azurerm_container_registry.acr,
    azurerm_application_insights.main,
    azurerm_container_group.elasticsearch
  ]
}

# ============================================================
# FASE 7: APP SERVICES
# ============================================================

resource "azurerm_service_plan" "plan_backend" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B2"

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_service_plan" "plan_frontend" {
  name                = var.app_service_plan_name_web
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"

  depends_on = [azurerm_resource_group.rg]
}

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

    cors {
      allowed_origins = [
        "https://${var.app_service_name_web}.azurewebsites.net",
        "http://localhost:3000"
      ]
      support_credentials = true
    }
  }

  app_settings = {
    # 🗄️ Base de datos SQL Server (TEXTO PLANO — como el antiguo)
    "SQL_SERVER"                              = azurerm_mssql_server.sql_server.fully_qualified_domain_name
    "SQL_DATABASE"                            = var.database_name
    "SQL_USER"                                = var.sql_admin_login
    "SQL_PASSWORD"                            = var.sql_admin_password
    "SPRING_DATASOURCE_DRIVER_CLASS_NAME"     = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
    "SPRING_DATASOURCE_URL"                   = "jdbc:sqlserver://${azurerm_mssql_server.sql_server.fully_qualified_domain_name}:1433;databaseName=${var.database_name};encrypt=true;trustServerCertificate=false;loginTimeout=30;"
    "SPRING_DATASOURCE_USERNAME"              = var.sql_admin_login
    "SPRING_DATASOURCE_PASSWORD"              = var.sql_admin_password

    # 🔍 Application Insights — DESHABILITADO (como el antiguo)
    "APPLICATIONINSIGHTS_ENABLED"             = "false"
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "disabled"

    # 📊 OpenTelemetry (adaptado a ACI)
    "JAVA_TOOL_OPTIONS"           = "-javaagent:/home/site/wwwroot/otel/opentelemetry-javaagent.jar"
    "OTEL_SERVICE_NAME"           = "spring-boot-backend"
    "OTEL_EXPORTER_OTLP_ENDPOINT" = var.enable_otel == "true" ? "http://${azurerm_container_group.otel_collector[0].ip_address}:4318" : ""
    "OTEL_EXPORTER_OTLP_PROTOCOL" = "http/protobuf"
    "OTEL_EXPORTER_OTLP_HTTP"     = var.enable_otel == "true" ? "http://${azurerm_container_group.otel_collector[0].ip_address}:4318" : ""
    "OTEL_TRACES_EXPORTER"        = "otlp"
    "OTEL_METRICS_EXPORTER"       = "otlp"
    "OTEL_LOGS_EXPORTER"          = "otlp"

    # 🌐 Aplicación Spring Boot
    "SERVER_PORT"                 = "8080"
    "SPRING_APPLICATION_NAME"     = "app"
    "SPRING_PROFILES_ACTIVE"      = "production"
    "SERVER_SERVLET_CONTEXT_PATH" = "/api"

    # 🗂️ Azure Blob Storage
    "CONNECTION_STRING_BLOB_STORAGE" = azurerm_storage_account.storage.secondary_connection_string
    "CONTAINER_NAME_CUSTOMER"       = "images"
    "CONTAINER_NAME_ORDER"          = "images"

    # 🧩 JPA / Hibernate
    "SPRING_JPA_HIBERNATE_DDL_AUTO"           = "create-drop"
    "SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT" = "org.hibernate.dialect.SQLServerDialect"
    "SPRING_JPA_SHOW_SQL"                     = "false"

    # 🔍 Elasticsearch
    "ELASTICSEARCH_ENABLED" = "false"
    "ELASTICSEARCH_PORT"    = "9200"
  }

  depends_on = [
    azurerm_service_plan.plan_backend,
    azurerm_mssql_database.database,
    azurerm_key_vault_secret.db_database,
    azurerm_key_vault_secret.db_username,
    azurerm_key_vault_secret.db_password,
    azurerm_container_group.otel_collector,
    azurerm_container_group.elasticsearch
  ]
}

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
    "REACT_APP_API_URL"     = "https://${var.app_service_name}.azurewebsites.net"
    "REACT_APP_ENVIRONMENT" = "production"

    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "20-lts"

    # 🗂️ Azure Blob Storage (acceso via Managed Identity)
    "AZURE_STORAGE_ACCOUNT_NAME"   = azurerm_storage_account.storage.name
    "AZURE_STORAGE_CONTAINER_NAME" = "images"
    "AZURE_STORAGE_ENDPOINT"       = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net"
  }

  depends_on = [azurerm_service_plan.plan_frontend]
}

# Frontend Blob Reader Role (Managed Identity)
resource "azurerm_role_assignment" "frontend_blob_reader" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_web_app.frontend.identity[0].principal_id

  depends_on = [
    azurerm_linux_web_app.frontend,
    azurerm_storage_account.storage
  ]
}

resource "azurerm_role_assignment" "backend_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id

  depends_on = [
    azurerm_linux_web_app.backend,
    azurerm_key_vault.kv
  ]
}

resource "azurerm_app_service_virtual_network_swift_connection" "backend_integration" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.subnet_integration.id

  depends_on = [
    azurerm_linux_web_app.backend,
    azurerm_subnet.subnet_integration
  ]
}

# ============================================================
# FASE 8: PRIVATE DNS ZONES
# ============================================================

# Private DNS Zone para App Services
resource "azurerm_private_dns_zone" "appservice" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "appservice_link" {
  name                  = "vnet-link-appservice"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.appservice.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.appservice]
}

# Private DNS Zone para Blob Storage
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_link" {
  name                  = "vnet-link-blob"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false

  depends_on = [azurerm_private_dns_zone.blob]
}

# ============================================================
# FASE 9: PRIVATE ENDPOINTS
# ============================================================

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

  private_dns_zone_group {
    name                 = "dns-group-backend"
    private_dns_zone_ids = [azurerm_private_dns_zone.appservice.id]
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_linux_web_app.backend,
    azurerm_private_dns_zone.appservice
  ]
}

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

  private_dns_zone_group {
    name                 = "dns-group-frontend"
    private_dns_zone_ids = [azurerm_private_dns_zone.appservice.id]
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_linux_web_app.frontend,
    azurerm_private_dns_zone.appservice
  ]
}

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

  private_dns_zone_group {
    name                 = "dns-group-blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_storage_account.storage,
    azurerm_private_dns_zone.blob
  ]
}

# ============================================================
# FASE 10: APPLICATION GATEWAY
# ============================================================

resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.rg]
}

locals {
  backend_pool_frontend_name     = "pool-frontend"
  backend_pool_backend_name      = "pool-backend"
  frontend_port_name_https       = "frontend-port-https"
  frontend_ip_configuration_name = "frontend-ip"
  http_setting_frontend_name     = "setting-frontend"
  http_setting_backend_name      = "setting-backend"
  listener_name_https            = "https-listener"
  request_routing_rule_name      = "routing-rule-https"
  ssl_certificate_name           = "cert-app-dojo"
  url_path_map_name              = "url-path-map"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.resource_group_name}-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.subnet_agw.id
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  # Puerto HTTPS (443)
  frontend_port {
    name = local.frontend_port_name_https
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  # Certificado SSL/TLS (PFX)
  ssl_certificate {
    name     = local.ssl_certificate_name
    data     = var.cert_data
    password = var.cert_password
  }

  # Backend Pool - Frontend (IP Privada via Private Endpoint)
  backend_address_pool {
    name         = local.backend_pool_frontend_name
    ip_addresses = [azurerm_private_endpoint.frontend_pe.private_service_connection[0].private_ip_address]
  }

  # Backend Pool - Backend (IP Privada via Private Endpoint)
  backend_address_pool {
    name         = local.backend_pool_backend_name
    ip_addresses = [azurerm_private_endpoint.backend_pe.private_service_connection[0].private_ip_address]
  }

  # Health Probe - Frontend
  probe {
    name                                      = "health-probe-frontend"
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # Health Probe - Backend
  probe {
    name                                      = "probe-backend"
    protocol                                  = "Https"
    path                                      = "/api/customer"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # HTTP Settings - Frontend
  backend_http_settings {
    name                                = local.http_setting_frontend_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = false
    host_name                           = azurerm_linux_web_app.frontend.default_hostname
    probe_name                          = "health-probe-frontend"
  }

  # HTTP Settings - Backend
  backend_http_settings {
    name                                = local.http_setting_backend_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = false
    host_name                           = azurerm_linux_web_app.backend.default_hostname
    probe_name                          = "probe-backend"
  }

  # Listener HTTPS con certificado SSL
  http_listener {
    name                           = local.listener_name_https
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"
    ssl_certificate_name           = local.ssl_certificate_name
  }

  # URL Path Map — enrutamiento basado en rutas
  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.backend_pool_frontend_name
    default_backend_http_settings_name = local.http_setting_frontend_name

    # Regla para Frontend - /web/*
    path_rule {
      name                       = "frontend-rule"
      paths                      = ["/web/*"]
      backend_address_pool_name  = local.backend_pool_frontend_name
      backend_http_settings_name = local.http_setting_frontend_name
    }

    # Regla para Backend - /customer*
    path_rule {
      name                       = "backend-rule"
      paths                      = ["/api/customer*"]
      backend_address_pool_name  = local.backend_pool_backend_name
      backend_http_settings_name = local.http_setting_backend_name
    }

    # Regla para Backend - /order*
    path_rule {
      name                       = "backend-rule2"
      paths                      = ["/api/order*"]
      backend_address_pool_name  = local.backend_pool_backend_name
      backend_http_settings_name = local.http_setting_backend_name
    }

    # Regla para Backend - /otel/v1/traces*
    path_rule {
      name                       = "backend-rule3"
      paths                      = ["/api/otel/v1/traces*"]
      backend_address_pool_name  = local.backend_pool_backend_name
      backend_http_settings_name = local.http_setting_backend_name
    }
  }

  # Regla de enrutamiento HTTPS con path-based routing
  request_routing_rule {
    name               = local.request_routing_rule_name
    rule_type          = "PathBasedRouting"
    http_listener_name = local.listener_name_https
    url_path_map_name  = local.url_path_map_name
    priority           = 100
  }

  depends_on = [
    azurerm_private_endpoint.frontend_pe,
    azurerm_private_endpoint.backend_pe,
    azurerm_private_dns_zone_virtual_network_link.appservice_link,
    azurerm_public_ip.appgw_pip
  ]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Purpose     = "LoadBalancer"
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "backend_url" {
  value = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "frontend_url" {
  value = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "otel_collector_ip" {
  value = var.enable_otel == "true" ? azurerm_container_group.otel_collector[0].ip_address : "Not deployed"
}

output "appgw_public_ip" {
  value = azurerm_public_ip.appgw_pip.ip_address
}
