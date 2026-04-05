# -----------------------------------------------------------------------------
# Composition Root
# This file wires all modules together. Each module maps to one or more
# Well-Architected pillars. The dependency graph is:
#   hub-networking → spoke-networking → aks-cluster
#                                     → acr (Private Endpoint into spoke)
#                                     → key-vault (Private Endpoint into spoke)
#   monitoring ← aks-cluster (diagnostic settings)
#   governance ← aks-cluster (policy assignments)
# -----------------------------------------------------------------------------

locals {
  # Consistent naming convention: {project}-{environment}-{region}
  name_prefix = "${var.project_name}-${var.environment}"

  # Merge user tags with mandatory tags
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    WAFPillar   = "all"
  })
}

# ---- Resource Groups ----
# Separate RGs for hub and spoke — different lifecycle, different RBAC.

resource "azurerm_resource_group" "hub" {
  name     = "rg-${local.name_prefix}-hub"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "spoke" {
  name     = "rg-${local.name_prefix}-spoke"
  location = var.location
  tags     = local.common_tags
}

# ---- Hub Networking ----
# WAF Pillars: Security (centralized egress), Ops Excellence (single pane of glass)

module "hub_networking" {
  source              = "./modules/hub-networking"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  name_prefix         = local.name_prefix
  vnet_address_space  = var.hub_vnet_address_space
  enable_bastion      = var.enable_bastion
  tags                = local.common_tags
}

# ---- Spoke Networking ----
# WAF Pillars: Security (NSGs, UDR to firewall), Performance (dedicated subnets)

module "spoke_networking" {
  source              = "./modules/spoke-networking"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  name_prefix         = local.name_prefix
  vnet_address_space  = var.spoke_vnet_address_space

  # Peering to hub
  hub_vnet_id   = module.hub_networking.vnet_id
  hub_vnet_name = module.hub_networking.vnet_name
  hub_rg_name   = azurerm_resource_group.hub.name

  # UDR: all spoke egress → hub firewall
  firewall_private_ip = module.hub_networking.firewall_private_ip

  tags = local.common_tags
}

# ---- Monitoring ----
# WAF Pillar: Ops Excellence (observability), Reliability (alerting)
# Created before AKS because the cluster needs the workspace ID.

module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  name_prefix         = local.name_prefix
  enable_grafana      = var.enable_grafana
  tags                = local.common_tags
}

# ---- ACR ----
# WAF Pillars: Security (private endpoint), Performance (backbone pulls)

module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  name_prefix         = local.name_prefix

  # Private Endpoint into spoke VNet
  subnet_id                = module.spoke_networking.pe_subnet_id
  private_dns_zone_ids     = [module.hub_networking.acr_private_dns_zone_id]
  log_analytics_workspace_id = module.monitoring.workspace_id

  tags = local.common_tags
}

# ---- Key Vault ----
# WAF Pillar: Security (secrets management, RBAC, private endpoint)

module "key_vault" {
  source              = "./modules/key-vault"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  name_prefix         = local.name_prefix

  subnet_id            = module.spoke_networking.pe_subnet_id
  private_dns_zone_ids = [module.hub_networking.kv_private_dns_zone_id]

  tags = local.common_tags
}

# ---- AKS Cluster ----
# WAF Pillars: ALL FIVE — this is the core workload.

module "aks_cluster" {
  source              = "./modules/aks-cluster"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  name_prefix         = local.name_prefix
  kubernetes_version  = var.kubernetes_version

  # Networking
  vnet_subnet_id = module.spoke_networking.aks_subnet_id

  # Identity
  aks_admin_group_id = var.aks_admin_group_id

  # Node pools
  system_node_count      = var.system_node_count
  system_node_vm_size    = var.system_node_vm_size
  general_node_min_count = var.general_node_min_count
  general_node_max_count = var.general_node_max_count
  general_node_vm_size   = var.general_node_vm_size
  enable_spot_pool       = var.enable_spot_pool

  # Monitoring
  log_analytics_workspace_id = module.monitoring.workspace_id

  # ACR integration
  acr_id = module.acr.acr_id

  # DNS
  private_dns_zone_id = module.hub_networking.aks_private_dns_zone_id

  tags = local.common_tags
}

# ---- Governance ----
# WAF Pillars: Security (policy guardrails), Ops Excellence (compliance)

module "governance" {
  source              = "./modules/governance"
  resource_group_name = azurerm_resource_group.spoke.name
  aks_cluster_id      = module.aks_cluster.cluster_id
  enable_defender     = var.enable_defender
}
