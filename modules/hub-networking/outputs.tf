output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "aks_private_dns_zone_id" {
  value = azurerm_private_dns_zone.aks.id
}

output "acr_private_dns_zone_id" {
  value = azurerm_private_dns_zone.acr.id
}

output "kv_private_dns_zone_id" {
  value = azurerm_private_dns_zone.kv.id
}
