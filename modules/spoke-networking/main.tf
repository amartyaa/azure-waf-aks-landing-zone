# Spoke Networking Module
# Creates the spoke VNet with AKS and PE subnets, VNet peering to hub,
# NSGs, and UDR routing all egress through the hub's Azure Firewall.

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-spoke"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# ---- Subnets ----

# AKS Subnet: /22 = 1022 usable IPs.
# With Azure CNI Overlay, pods get their own overlay CIDR so this is for nodes only.
resource "azurerm_subnet" "aks" {
  name                 = "snet-${var.name_prefix}-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 6, 0)] # /22
}

# Private Endpoint Subnet: for ACR, Key Vault, and other PaaS private links.
resource "azurerm_subnet" "pe" {
  name                 = "snet-${var.name_prefix}-pe"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 4)] # /24

  # Required for Private Endpoints
  private_endpoint_network_policies = "Enabled"
}

# ---- NSGs ----
# Defense in depth: even if Calico policies fail, NSGs block unexpected traffic.

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow inbound from hub firewall subnet only
  security_rule {
    name                       = "AllowHubFirewall"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/26" # Firewall subnet
    destination_address_prefix = "*"
  }

  # Allow internal load balancer traffic
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# ---- VNet Peering ----
# Bidirectional peering: spoke ↔ hub. Allow forwarded traffic for firewall routing.

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke"
  resource_group_name          = var.hub_rg_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  allow_gateway_transit        = false
}

# ---- Route Table (UDR) ----
# Force all egress through the hub's Azure Firewall.
# This is critical for centralized logging and egress filtering.

resource "azurerm_route_table" "aks_to_firewall" {
  name                          = "rt-${var.name_prefix}-aks"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = var.tags
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "default-to-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.aks_to_firewall.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

resource "azurerm_subnet_route_table_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  route_table_id = azurerm_route_table.aks_to_firewall.id
}
