variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_prefix" { type = string }
variable "vnet_address_space" { type = string }
variable "enable_bastion" { type = bool }
variable "tags" { type = map(string) }
