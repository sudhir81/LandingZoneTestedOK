terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstate13334c"   # from your echo $SA
    container_name       = "tfstate"
    key                  = "landingzone-preprod.tfstate"
  }
}
