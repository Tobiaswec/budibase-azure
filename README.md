# How to setup Budibase on Azure with persistent storage and SSL/TLS

Since there isn't much available documentation on configuring Budibase on Azure with persistent storage and valid SSL certificates, I decided to create my own guide. While you can run Budibase on Azure App Service as a Web App and obtain SSL certificates with relative ease, it lacks support for persistent storage. I've experimented extensively with this, and the primary challenge lies in the inability to mount an Azure File Share to the `/home` directory. Even attempting to change the Budibase data directory to `/data` and mounting the Azure File Share to this location proved problematic due to Linux permission issues. Although you can set it up, you won't be able to store or access apps successfully.

Documentation for deploying Budibase on Azure App Service (AAS) can be located at: <https://docs.budibase.com/docs/azure-app-service>

## Solution
The solution that worked for me: setting up Budibase on Azure Container Instance (ACI). ACI allows you to mount the Azure File Share to the `/home` directory, which enables persistent storage. However, ACIs do not offer built-in SSL/TLS support, so you'll need to run a proxy like Nginx or Caddy.

Here's where I encountered another challenge. Budibase doesn't easily allow you to change the port on which its internal proxy (Nginx) runs within the `budibase/budibase-aas` image. Unfortunately, I couldn't find any documentation addressing this issue. While it's possible to set up Nginx to forward traffic to the default Budibase port 80, you'll need to handle SSL/TLS certificates on your own since there's no built-in certbot for Let's Encrypt.

In my experience, Caddy was the way to go. It's straightforward to set up and automatically renews certificates using Let's Encrypt. However, Caddy needs to run on ports 80 and 443, which conflicts with Budibase running on port 80. To resolve this, you'll need to create your custom Budibase image and modify the Nginx configuration.


In this tutorial, I employed Terraform to establish the infrastructure, as I'm a strong advocate of infrastructure as code. However, you have the flexibility to utilize tools like Bicep or other Azure Resource Manager (ARM) templates if you prefer.

By following this guide, you should find it straightforward to configure Budibase on Azure, complete with persistent storage and SSL, in a matter of minutes.

For further reading and documentation on setting up Budibase on Azure or SSL/TLS for Azure Container Instances (ACI), you can refer to the following resources:
- Budibase on ACI: <https://docs.budibase.com/docs/azure-container-instances>
- ACI Proxy Nginx: <https://learn.microsoft.com/en-us/azure/container-instances/container-instances-container-group-ssl>
- ACI Proxy Caddy: <https://learn.microsoft.com/en-us/azure/container-instances/container-instances-container-group-automatic-ssl>

## Create Budibase Custom Image
Setting up your custom image with a modified internal proxy port (Nginx) is a straightforward process when working with the [Dockerfile](Dockerfile).
```Dockerfile
FROM budibase/budibase-aas:latest

RUN sed -i 's/listen\s\+80 default_server;/listen 10000 default_server;/' /etc/nginx/sites-available/default && \
    sed -i 's/listen\s\+\[::\]:80 default_server;/listen [::]:10000 default_server;/' /etc/nginx/sites-available/default
```

To upload this Dockerfile to the registry of your choice, you can utilize basic Docker commands, such as:
```
docker build . -t YOUR_REGISRY_URL/company-budibase-aas:latest
docker login -u YOUR_USERNAME -p YOUR_PASSWORD YOUR_REGISRY_URL
docker push YOUR_REGISRY_URL/company-budibase-aas:latest
```

Alternatively, you can opt for a pipeline solution like JetBrains Space by using a [.space.kts](.space.kts) script:
```
job("Build, push budibase image") {
    kaniko(displayName = "Build image and push into container registry") {
        build {
            context = "."
        }

        push("YOUR_REGISTRY_URL/company-budibase-aas:latest") 
    }
}
```

## Setup ACI and Azure Infrastructure using Terraform
Once the custom image has been successfully created and pushed to a container registry, you can proceed to set up Azure infrastructure. I use Azure Key Vault for managing secrets and Terraform workspaces for deploying to different environments. However, feel free to remove these components if they are not required for your specific use case.

I'll skip the Azure basics setup, such as resource groups and other foundational elements, but you can find more details in the `terraform` folder if needed.

### Budibase ACI Setup:
```tf
resource "azurerm_container_group" "budibase" {
  name                = "budibase-${terraform.workspace}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_name_label      = "company-budibase-${terraform.workspace}"
  os_type             = "Linux"

  image_registry_credential { #This is needed for private registry if you use a public one just remove it
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
```

### Storage Accounts:

File shares are essential for ensuring persistent storage of Budibase data and also for Caddy to store certificate data. Without persistent storage, Caddy would regenerate certificates upon each startup. This could potentially result in Caddy being blocked from creating new certificates for your domain due to rate limits or other issues. Therefore, it's crucial to have these file shares in place to maintain the integrity and availability of your data and certificates.

```tf
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
```



