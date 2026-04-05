output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks_cluster.cluster_name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = module.aks_cluster.cluster_id
}

output "aks_get_credentials_command" {
  description = "az CLI command to get kubectl credentials."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.spoke.name} --name ${module.aks_cluster.cluster_name} --overwrite-existing"
}

output "hub_vnet_id" {
  value = module.hub_networking.vnet_id
}

output "spoke_vnet_id" {
  value = module.spoke_networking.vnet_id
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_uri" {
  value = module.key_vault.vault_uri
}

output "log_analytics_workspace_id" {
  value = module.monitoring.workspace_id
}
