# Key Vault Module
# RBAC-based access (no access policies), soft-delete, purge protection, Private Endpoint.

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = "kv-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  # SECURITY: RBAC mode — no legacy access policies.
  enable_rbac_authorization = true

  # RELIABILITY: Soft-delete protects against accidental deletion.
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  # SECURITY: Private access only
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# Grant the deployer (current user/SP) Key Vault Administrator
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---- Private Endpoint ----
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-${var.name_prefix}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group-kv"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}
