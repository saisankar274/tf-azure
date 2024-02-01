terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tf-backend-all"
    storage_account_name = "tfstate9eb37f72f5ef"
    container_name       = "tfstate-dev"
    key                  = "terraform.tfstate"
  }
}