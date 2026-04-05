output "cluster_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federation."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}
