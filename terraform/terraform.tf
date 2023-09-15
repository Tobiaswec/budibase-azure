// -------------- TERRAFORM PROVIDER --------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.43.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = "YOUR_SUBSCRIPTION_ID" #replace
  tenant_id       = "YOUR_TENANT_ID" #replace
}

// -------------- AZURE RESOURCE GROUP --------------
resource "azurerm_resource_group" "rg" {
  name     = "company-resources-${terraform.workspace}"
  location = "West Europe"

  tags = {
    environment = terraform.workspace
  }
}

// -------------- TERRAFORM KEY VAULT --------------
data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "company-key-vault" {
  name                        = "company-keys-${terraform.workspace}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
  sku_name                    = "standard"

  tags = {
    environment = terraform.workspace
  }
}
