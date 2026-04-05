output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "pe_subnet_id" {
  value = azurerm_subnet.pe.id
}
