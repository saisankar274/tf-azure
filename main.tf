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
    environment = "all"
  }
}

#Generic Resource Group. Applicable for only Development environment.
resource "azurerm_resource_group" "rg" {
  name     = "rg-tf-dev"
  location = "eastus2"

  tags = {
    environment = "development"
  }
}

#Backend Storage Account. Common for all environments.
resource "azurerm_storage_account" "backend-sa" {
  name                     = "tfstate9eb37f72f5ef"
  resource_group_name      = azurerm_resource_group.backend-rg.name
  location                 = azurerm_resource_group.backend-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "all"
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

#Integrating already existing resource group and modifying tags
resource "azurerm_resource_group" "manual_rg_dev" {
  name     = var.manual_rg_name
  location = var.loc_name

  tags = {
    environment        = "development",
    created-via        = "manual",
    integrated-with-tf = "true"
  }
}

#Integrating already existing storage account but not doing any changes
resource "azurerm_storage_account" "manual_stg_dev" {
  name                            = "stgmanualdev"
  resource_group_name             = azurerm_resource_group.manual_rg_dev.name
  location                        = "eastus2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = false
  is_hns_enabled                  = true

  tags = {
    environment        = "development",
    created-via        = "manual",
    integrated-with-tf = "true"
  }
}

#Creating a table in manually created storage account after importing that into Terraform
resource "azurerm_storage_table" "tf_table_dev" {
  name                 = "ClientDetails"
  storage_account_name = azurerm_storage_account.manual_stg_dev.name
}

#Creating table entities in the table
resource "azurerm_storage_table_entity" "tf_table_entities_dev" {
  storage_account_name = azurerm_storage_account.manual_stg_dev.name
  table_name           = azurerm_storage_table.tf_table_dev.name
  row_key              = "C10001"
  partition_key        = "Client-1"
  entity = {
    workspace_id  = "/subscriptions/587189da-5588-48cd-a738-9eb37f72f5ef/resourceGroups/databricks/"
    workspace_url = "https://adb1234567980.1/databricks.net"
    cluster_id    = "12345-0sgh-2sdhj"
  }
}

#Integrating already existing azure data factory but not doing any changes
resource "azurerm_data_factory" "manual_adf_dev" {
  name                = "adf-manual-dev"
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.manual_rg_dev.name
  identity {
    type         = "SystemAssigned"
    identity_ids = []
  }

  tags = {
    environment        = "development",
    created-via        = "manual",
    integrated-with-tf = "true"
  }

  timeouts {

  }
}

#Creating a linked service from Terraform
resource "azurerm_data_factory_linked_service_azure_table_storage" "tf_adf_ls_dev" {
  name              = "LS_Automated_stgmanualdev"
  data_factory_id   = "/subscriptions/587189da-5588-48cd-a738-9eb37f72f5ef/resourceGroups/rg-manual-dev/providers/Microsoft.DataFactory/factories/adf-manual-dev"
  connection_string = var.STGMANUAL_CONNECTION_STRING
}

#Creating a dataset from Terraform
resource "azurerm_data_factory_custom_dataset" "tf_adf_dataset_dev" {
  name            = "DS_Automated_ClientDetails"
  data_factory_id = "/subscriptions/587189da-5588-48cd-a738-9eb37f72f5ef/resourceGroups/rg-manual-dev/providers/Microsoft.DataFactory/factories/adf-manual-dev"
  linked_service {
    name = azurerm_data_factory_linked_service_azure_table_storage.tf_adf_ls_dev.name
  }
  type                 = "AzureTable"
  folder               = "Automated_Deployments_Datasets"
  type_properties_json = <<JSON
  {
    "tableName": "ClientDetails"
  }
  JSON
}

#Creating a adf pipeline from Terraform
resource "azurerm_data_factory_pipeline" "tf_adf_pipeline_dev" {
  name            = "Pipeline_Automated_Dev"
  data_factory_id = "/subscriptions/587189da-5588-48cd-a738-9eb37f72f5ef/resourceGroups/rg-manual-dev/providers/Microsoft.DataFactory/factories/adf-manual-dev"
  folder          = "Automated_Deployments"
  parameters = {
    CLIENT = "Client-1"
  }
  activities_json = <<JSON
  [
    {
        "name": "LOOKUP_CLIENT_TABLE",
        "type": "Lookup",
        "dependsOn": [],
        "policy": {
            "timeout": "0.12:00:00",
            "retry": 0,
            "retryIntervalInSeconds": 30,
            "secureOutput": false,
            "secureInput": false
        },
        "userProperties": [],
        "typeProperties": {
            "source": {
                "type": "AzureTableSource",
                "azureTableSourceQuery": {
                    "value": "Partitionkey eq '@{pipeline().parameters.CLIENT}'",
                    "type": "Expression"
                },
                "azureTableSourceIgnoreTableNotFound": false
            },
            "dataset": {
                "referenceName": "DS_Automated_ClientDetails",
                "type": "DatasetReference"
            },
            "firstRowOnly": true
        }
    }
  ]
  JSON
}