# ---- Core ----
variable "subscription_id" {
  description = "Azure Subscription ID."
  type        = string
}

variable "location" {
  description = "Azure region. Use paired regions for DR readiness."
  type        = string
  default     = "centralindia"
}

variable "environment" {
  description = "Environment: dev, staging, or prod. Drives naming, sizing, and safety toggles."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be: dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Short project identifier for resource naming."
  type        = string
  default     = "waf-aks"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ---- Networking ----
variable "hub_vnet_address_space" {
  description = "CIDR for Hub VNet."
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_vnet_address_space" {
  description = "CIDR for Spoke VNet."
  type        = string
  default     = "10.1.0.0/16"
}

# ---- Identity ----
variable "aks_admin_group_id" {
  description = "Azure AD group Object ID for cluster-admin RBAC."
  type        = string
}

# ---- AKS ----
variable "kubernetes_version" {
  description = "AKS Kubernetes version."
  type        = string
  default     = "1.29"
}

variable "system_node_count" {
  description = "System pool node count. Min 3 for production (one per AZ)."
  type        = number
  default     = 3
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "general_node_min_count" {
  type    = number
  default = 2
}

variable "general_node_max_count" {
  type    = number
  default = 10
}

variable "general_node_vm_size" {
  type    = string
  default = "Standard_D8s_v5"
}

variable "enable_spot_pool" {
  description = "Create Spot VM pool for non-critical workloads."
  type        = bool
  default     = true
}

# ---- Feature Toggles ----
variable "enable_bastion" {
  description = "Deploy Azure Bastion for kubectl access."
  type        = bool
  default     = true
}

variable "enable_defender" {
  description = "Enable Defender for Containers."
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Deploy Azure Managed Grafana."
  type        = bool
  default     = false
}
