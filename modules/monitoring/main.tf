# Monitoring Module
# Log Analytics Workspace as the central sink for all diagnostic data.
# Container Insights for AKS-specific observability.
# Optional Azure Managed Grafana for dashboards.

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 90 # 90 days is a good balance of cost vs. forensic depth
  tags                = var.tags
}

# Container Insights solution — enables the Insights tab in the Azure Portal
# and structured queries over container logs in Log Analytics.
resource "azurerm_log_analytics_solution" "containers" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

# ---- Alert Rules ----
# Alert on node-level and pod-level issues. Action group routes to email/Teams/PagerDuty.

resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-${var.name_prefix}-ops"
  resource_group_name = var.resource_group_name
  short_name          = "ops-alert"
  tags                = var.tags

  # Configure your notification channels here:
  # email_receiver {
  #   name          = "ops-team"
  #   email_address = "ops@example.com"
  # }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "node_not_ready" {
  name                = "alert-${var.name_prefix}-node-not-ready"
  location            = var.location
  resource_group_name = var.resource_group_name
  description         = "Alert when AKS nodes enter NotReady state."
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"

  criteria {
    query = <<-QUERY
      KubeNodeInventory
      | where Status == "NotReady"
      | summarize count() by Computer, bin(TimeGenerated, 5m)
    QUERY

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pod_restart_loop" {
  name                = "alert-${var.name_prefix}-pod-restart"
  location            = var.location
  resource_group_name = var.resource_group_name
  description         = "Alert on pods restarting more than 5 times in 15 minutes."
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"

  criteria {
    query = <<-QUERY
      KubePodInventory
      | where PodRestartCount > 5
      | summarize count() by PodName = Name, Namespace, bin(TimeGenerated, 5m)
    QUERY

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }
}

# ---- Managed Grafana (Optional) ----
resource "azurerm_dashboard_grafana" "main" {
  count               = var.enable_grafana ? 1 : 0
  name                = "grafana-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  zone_redundancy_enabled = false
  tags                = var.tags

  azure_monitor_workspace_integrations {
    resource_id = azurerm_log_analytics_workspace.main.id
  }
}
