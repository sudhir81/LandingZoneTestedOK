# Auth via Azure CLI: az login
provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "all"
}

provider "azuread" {}

provider "azapi" {}

data "azurerm_subscription" "current" {
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}
