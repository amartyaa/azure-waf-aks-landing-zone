provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = var.environment == "dev" ? true : false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = var.environment == "prod" ? true : false
    }
  }
  subscription_id = var.subscription_id
}

provider "azuread" {}
