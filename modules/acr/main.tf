# ACR Module
# Premium SKU for geo-replication support and Private Endpoint.
# Images pulled over Azure backbone — no public internet, no egress cost.

resource "azurerm_container_registry" "acr" {
  # ACR names must be globally unique and alphanumeric only.
  name                = replace("acr${var.name_prefix}", "-", "")
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Premium" # Required for Private Endpoint + geo-replication
  admin_enabled       = false     # SECURITY: Use RBAC, not admin credentials
  tags                = var.tags

  # SECURITY: Only allow access via Private Endpoint
  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"
}

# ---- Private Endpoint ----
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${var.name_prefix}-acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group-acr"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}

# ---- Diagnostic Logging ----
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
  }
}
