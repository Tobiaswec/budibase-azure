// -------------- BUDIBASE CONTAINER INSTANCE --------------
resource "azurerm_container_group" "budibase" {
  name                = "budibase-${terraform.workspace}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_name_label      = "company-budibase-${terraform.workspace}"
  os_type             = "Linux"

  image_registry_credential {
    password = data.azurerm_key_vault_secret.docker-registry-token.value #replace with your password
    server   = "YOUR_DOCKER_REGISTRY" #replace with your registry
    username = local.docker-registry-user #replace with your user
  }

  container {
    name   = "budibase-${terraform.workspace}"
    image  = "YOUR_DOCKER_REGISTRY/company-budibase-aas:latest"
    cpu    = "1"
    memory = "2"

    volume {
      name                 = "budibase-${terraform.workspace}-volume"
      share_name           = azurerm_storage_share.share-budibase.name
      storage_account_name = azurerm_storage_account.storage-budibase.name
      storage_account_key  = azurerm_storage_account.storage-budibase.primary_access_key
      mount_path           = "/home"
    }

  }

  container {
    name   = "caddy"
    image  = "caddy"
    cpu    = "0.5"
    memory = "0.5"

    ports {
      port     = 443
      protocol = "TCP"
    }

    ports {
      port     = 80
      protocol = "TCP"
    }

    volume {
      name                 = "budibase-caddy-${terraform.workspace}-volume"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.storage-budibase.name
      storage_account_key  = azurerm_storage_account.storage-budibase.primary_access_key
      share_name           = azurerm_storage_share.share-budibase-caddy.name
    }

    commands = ["caddy", "reverse-proxy", "--from", "company-budibase-${terraform.workspace}.westeurope.azurecontainer.io", "--to", "localhost:10000"] #replace with your registry - Domain must match dns_name_label or custom domain
  }


  tags = {
    environment = terraform.workspace
  }
}

// -------------- BUDIBASE STORAGE --------------
resource "azurerm_storage_account" "storage-budibase" {
  name                     = "company-${terraform.workspace}budibase"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  tags = {
    environment = terraform.workspace
  }
}

resource "azurerm_storage_share" "share-budibase" {
  name                 = "company-share${terraform.workspace}budibase"
  storage_account_name = azurerm_storage_account.storage-budibase.name
  quota                = 50
}

resource "azurerm_storage_share" "share-budibase-caddy" {
  name                 = "company-share${terraform.workspace}budibasecaddy"
  storage_account_name = azurerm_storage_account.storage-budibase.name
  quota                = 1
}