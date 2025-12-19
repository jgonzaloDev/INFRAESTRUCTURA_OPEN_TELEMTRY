# ============================================================
# OUTPUTS - INFORMACIÓN DE RECURSOS DESPLEGADOS
# ============================================================

output "resource_group_name" {
  description = "Nombre del grupo de recursos"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Ubicación del grupo de recursos"
  value       = azurerm_resource_group.rg.location
}

# ============================================================
# NETWORKING
# ============================================================

output "vnet_name" {
  description = "Nombre de la Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "application_gateway_public_ip" {
  description = "IP pública del Application Gateway"
  value       = azurerm_public_ip.agw_pip.ip_address
}

# ============================================================
# APP SERVICES
# ============================================================

output "backend_url" {
  description = "URL del backend (Spring Boot API)"
  value       = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "frontend_url" {
  description = "URL del frontend (React App)"
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

# ============================================================
# DATABASE
# ============================================================

output "sql_server_fqdn" {
  description = "FQDN del servidor SQL"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Nombre de la base de datos"
  value       = azurerm_mssql_database.db.name
}

# ============================================================
# OBSERVABILITY
# ============================================================

output "application_insights_connection_string" {
  description = "Connection String de Application Insights"
  value       = azurerm_application_insights.appinsights.connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID del Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.id
}

output "otel_collector_ip" {
  description = "IP privada del OpenTelemetry Collector"
  value       = azurerm_container_group.otel_collector.ip_address
}

# ============================================================
# SECURITY
# ============================================================

output "key_vault_uri" {
  description = "URI del Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

# ============================================================
# STORAGE
# ============================================================

output "storage_account_name" {
  description = "Nombre de la cuenta de almacenamiento"
  value       = azurerm_storage_account.sa.name
}
