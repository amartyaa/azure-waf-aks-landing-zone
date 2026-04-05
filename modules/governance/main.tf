# Governance Module
# Azure Policy assignments for AKS security baseline.
# These enforce OPA Gatekeeper constraints via the Azure Policy Add-on.

# ---- Microsoft Defender for Containers ----
# Runtime threat detection + vulnerability scanning for ACR images.
resource "azurerm_security_center_subscription_pricing" "containers" {
  count         = var.enable_defender ? 1 : 0
  tier          = "Standard"
  resource_type = "ContainerRegistry"
}

resource "azurerm_security_center_subscription_pricing" "kubernetes" {
  count         = var.enable_defender ? 1 : 0
  tier          = "Standard"
  resource_type = "KubernetesService"
}

# ---- Azure Policy: AKS Baseline ----
# These policies are enforced by the Azure Policy add-on (OPA Gatekeeper)
# running inside the AKS cluster. Non-compliant resources are rejected at admission.

# Policy: No privileged containers
resource "azurerm_resource_policy_assignment" "no_privileged" {
  name                 = "no-privileged-containers"
  resource_id          = var.aks_cluster_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/95edb821-ddaf-4404-9732-666045e056b4"
  display_name         = "Do not allow privileged containers in AKS"
  enforce              = true
}

# Policy: Containers should only use allowed images
resource "azurerm_resource_policy_assignment" "allowed_images" {
  name                 = "allowed-container-images"
  resource_id          = var.aks_cluster_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469"
  display_name         = "Containers should only use allowed images"
  enforce              = true

  parameters = jsonencode({
    allowedContainerImagesRegex = {
      value = "^(mcr\\.microsoft\\.com|your-acr\\.azurecr\\.io)/.*$"
    }
  })
}

# Policy: No privilege escalation
resource "azurerm_resource_policy_assignment" "no_escalation" {
  name                 = "no-privilege-escalation"
  resource_id          = var.aks_cluster_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99"
  display_name         = "Do not allow privilege escalation in AKS"
  enforce              = true
}

# Policy: Internal load balancers only
resource "azurerm_resource_policy_assignment" "internal_lb" {
  name                 = "internal-lb-only"
  resource_id          = var.aks_cluster_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e"
  display_name         = "AKS should use internal load balancers only"
  enforce              = true
}
