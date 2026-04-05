output "policy_assignments" {
  description = "List of policy assignment IDs."
  value = [
    azurerm_resource_policy_assignment.no_privileged.id,
    azurerm_resource_policy_assignment.allowed_images.id,
    azurerm_resource_policy_assignment.no_escalation.id,
    azurerm_resource_policy_assignment.internal_lb.id,
  ]
}
