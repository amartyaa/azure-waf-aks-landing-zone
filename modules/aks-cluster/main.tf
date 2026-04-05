# AKS Cluster Module
# Private AKS with Azure AD RBAC, Managed Identity, Workload Identity,
# Azure CNI Overlay, Calico network policies, and multi-pool configuration.
# This single module touches all five WAF pillars.

# ---- Managed Identity ----
# User-Assigned MI for the control plane. No service principal secrets to rotate.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# The AKS identity needs Network Contributor on the spoke VNet subnet
# to attach nodes and create internal load balancers.
resource "azurerm_role_assignment" "aks_network" {
  scope                = var.vnet_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# The AKS identity needs Private DNS Zone Contributor to register
# the private API server's DNS record.
resource "azurerm_role_assignment" "aks_dns" {
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# ---- AKS Cluster ----
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name_prefix}"
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # SECURITY: Private API server — no public endpoint.
  private_cluster_enabled   = true
  private_dns_zone_id       = var.private_dns_zone_id
  private_cluster_public_fqdn_enabled = false

  # Networking: Azure CNI Overlay + Calico
  # Overlay gives pods their own CIDR, preventing VNet IP exhaustion.
  # Calico enforces pod-to-pod isolation via NetworkPolicy.
  network_profile {
    network_plugin    = "azure"
    network_plugin_mode = "overlay"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting" # Egress via hub firewall
    pod_cidr          = "192.168.0.0/16"     # Overlay pod CIDR (not routable outside cluster)
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  # Identity: User-Assigned Managed Identity (no SP secrets)
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # SECURITY: Azure AD RBAC — kubectl auth flows through Azure AD.
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.aks_admin_group_id]
  }

  # System node pool — CoreDNS, kube-proxy, metrics-server.
  # CriticalAddonsOnly taint keeps user workloads off system nodes.
  default_node_pool {
    name                 = "system"
    node_count           = var.system_node_count
    vm_size              = var.system_node_vm_size
    vnet_subnet_id       = var.vnet_subnet_id
    zones                = ["1", "2", "3"] # RELIABILITY: spread across AZs
    os_disk_type         = "Ephemeral"     # PERFORMANCE: faster, no remote disk I/O
    os_disk_size_gb      = 128
    max_pods             = 110
    type                 = "VirtualMachineScaleSets"
    only_critical_system_pods_allowed = true

    node_labels = {
      "pool" = "system"
    }

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # SECURITY: Enable Workload Identity for pod-level Azure access
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # OPS EXCELLENCE: Container Insights for observability
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # OPS EXCELLENCE: Azure Policy add-on for OPA Gatekeeper
  azure_policy_enabled = true

  # RELIABILITY: Auto-upgrade channel
  automatic_channel_upgrade = "patch"

  # RELIABILITY: Maintenance window — upgrades only during off-peak
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 6]
    }
  }

  depends_on = [
    azurerm_role_assignment.aks_network,
    azurerm_role_assignment.aks_dns,
  ]

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count, # Let autoscaler manage this
    ]
  }
}

# ---- General Purpose Node Pool ----
# Stateless application workloads. Autoscaler manages count.
resource "azurerm_kubernetes_cluster_node_pool" "general" {
  name                  = "general"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.general_node_vm_size
  zones                 = ["1", "2", "3"]
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = 128
  max_pods              = 110
  vnet_subnet_id        = var.vnet_subnet_id
  tags                  = var.tags

  # COST + RELIABILITY: autoscaler adjusts nodes based on demand
  enable_auto_scaling = true
  min_count           = var.general_node_min_count
  max_count           = var.general_node_max_count

  node_labels = {
    "pool" = "general"
  }

  upgrade_settings {
    max_surge = "33%"
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# ---- Spot Node Pool (Optional) ----
# COST: Up to 90% discount for non-critical workloads (batch, CI, dev).
# Eviction policy: Delete — nodes are removed when Azure reclaims capacity.
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count                 = var.enable_spot_pool ? 1 : 0
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.general_node_vm_size
  zones                 = ["1", "2", "3"]
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = 128
  max_pods              = 110
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1 # Pay up to on-demand price
  vnet_subnet_id        = var.vnet_subnet_id
  tags                  = var.tags

  enable_auto_scaling = true
  min_count           = 0
  max_count           = 5

  node_labels = {
    "pool"                                    = "spot"
    "kubernetes.azure.com/scalesetpriority"   = "spot"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  upgrade_settings {
    max_surge = "33%"
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# ---- ACR Pull Permission ----
# Grant AKS kubelet identity AcrPull so nodes can pull images from ACR.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
