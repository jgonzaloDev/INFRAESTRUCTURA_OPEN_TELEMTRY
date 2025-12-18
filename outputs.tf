# ============================================================
# OUTPUTS - INFORMACIÓN DE RECURSOS DESPLEGADOS
# ============================================================

output "resource_group_name" {
  description = "Nombre del grupo de recursos"
  value       = azurerm_resource_group.rg.name
}

output "backend_app_service_url" {
  description = "URL del App Service Backend (Spring Boot)"
  value       = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "frontend_app_service_url" {
  description = "URL del App Service Frontend (React)"
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "application_gateway_public_ip" {
  description = "IP pública del Application Gateway"
  value       = azurerm_public_ip.appgw_ip.ip_address
}

# ============================================================
# OBSERVABILIDAD
# ============================================================

output "log_analytics_workspace_id" {
  description = "ID del Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation Key de Application Insights"
  value       = azurerm_application_insights.app_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection String de Application Insights"
  value       = azurerm_application_insights.app_insights.connection_string
  sensitive   = true
}

output "otel_collector_ip" {
  description = "IP del OpenTelemetry Collector"
  value       = azurerm_container_group.otel_collector.ip_address
}

output "otel_collector_grpc_endpoint" {
  description = "Endpoint gRPC del OpenTelemetry Collector"
  value       = "http://${azurerm_container_group.otel_collector.ip_address}:4317"
}

output "otel_collector_http_endpoint" {
  description = "Endpoint HTTP del OpenTelemetry Collector"
  value       = "http://${azurerm_container_group.otel_collector.ip_address}:4318"
}

output "elasticsearch_ip" {
  description = "IP de Elasticsearch (si está habilitado)"
  value       = var.enable_elasticsearch ? azurerm_container_group.elasticsearch[0].ip_address : "No habilitado"
}

output "kibana_url" {
  description = "URL de Kibana (si está habilitado)"
  value       = var.enable_elasticsearch ? "http://${azurerm_container_group.kibana[0].ip_address}:5601" : "No habilitado"
}

# ============================================================
# BASE DE DATOS
# ============================================================

output "sql_server_fqdn" {
  description = "FQDN del SQL Server"
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "key_vault_uri" {
  description = "URI del Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

output "storage_account_name" {
  description = "Nombre de la Storage Account"
  value       = azurerm_storage_account.storage.name
}
