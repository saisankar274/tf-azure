#Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

#Backend Resource Group. Common for all environments.
resource "azurerm_resource_group" "backend-rg" {
  name     = "rg-tf-backend-all"
  location = "eastus2"

  tags = {
    environment = "development",
    environment = "production"
  }
}

#Generic Resource Group. Applicable for only Development environment.
resource "azurerm_resource_group" "rg" {
  name     = "rg-tf-dev"
  location = "eastus2"
}

#Backend Storage Account. Common for all environments.
resource "azurerm_storage_account" "backend-sa" {
  name                     = "tfstate9eb37f72f5ef"
  resource_group_name      = azurerm_resource_group.backend-rg.name
  location                 = azurerm_resource_group.backend-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "development",
    environment = "production"
  }
}

#Backend Container. Applicable for only Development environment.
resource "azurerm_storage_container" "tfstate-dev" {
  name                  = "tfstate-dev"
  storage_account_name  = azurerm_storage_account.backend-sa.name
  container_access_type = "private"
}

#Backend Container. Applicable for only Production environment.
resource "azurerm_storage_container" "tfstate-prod" {
  name                  = "tfstate-prod"
  storage_account_name  = azurerm_storage_account.backend-sa.name
  container_access_type = "private"
}