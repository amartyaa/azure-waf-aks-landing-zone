# Hub Networking Module
# Creates the hub VNet with Azure Firewall, Bastion, and Private DNS Zones.
# This is the centralized connectivity layer — all spoke egress routes through here.

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# ---- Subnets ----
# Azure Firewall requires a subnet named exactly "AzureFirewallSubnet".
# Bastion requires "AzureBastionSubnet". These are Azure-enforced names.

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 10, 0)] # /26
}

resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 10, 1)] # /26
}

resource "azurerm_subnet" "dns" {
  name                 = "snet-${var.name_prefix}-dns"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 1)] # /24
}

# ---- Azure Firewall ----
# Centralized egress: all spoke traffic routes through this firewall via UDR.
# Standard SKU is sufficient for most workloads. Premium adds IDPS + TLS inspection.

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.name_prefix}-fw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  name                = "fw-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Firewall rules: allow AKS-required outbound FQDNs
resource "azurerm_firewall_application_rule_collection" "aks_required" {
  name                = "aks-required-fqdns"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = var.resource_group_name
  priority            = 100
  action              = "Allow"

  rule {
    name             = "aks-control-plane"
    source_addresses = ["*"]
    target_fqdns = [
      "*.hcp.${var.location}.azmk8s.io",
      "mcr.microsoft.com",
      "*.data.mcr.microsoft.com",
      "management.azure.com",
      "login.microsoftonline.com",
      "packages.microsoft.com",
      "acs-mirror.azureedge.net",
    ]
    protocol {
      type = "Https"
      port = 443
    }
  }
}

# ---- Azure Bastion ----
# Secure RDP/SSH access to VMs inside the hub or peered spokes.
# Used for kubectl access to the private AKS cluster.

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-${var.name_prefix}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# ---- Private DNS Zones ----
# These zones resolve private endpoints. Linked to the hub VNet so
# DNS queries from peered spokes resolve correctly.

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks_hub" {
  name                  = "link-aks-hub"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_hub" {
  name                  = "link-acr-hub"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_hub" {
  name                  = "link-kv-hub"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}
