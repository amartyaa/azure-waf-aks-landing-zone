variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }
variable "private_dns_zone_ids" { type = list(string) }
variable "log_analytics_workspace_id" { type = string }
variable "tags" { type = map(string) }
