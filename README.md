# How to setup Budibase on Azure with persistent storage and SSL/TLS

Since there isn't much available documentation on configuring Budibase on Azure with persistent storage and valid SSL certificates, I decided to create my own guide. While you can run Budibase on Azure App Service as a Web App and obtain SSL certificates with relative ease, it lacks support for persistent storage. I've experimented extensively with this, and the primary challenge lies in the inability to mount an Azure File Share to the `/home` directory. Even attempting to change the Budibase data directory to `/data` and mounting the Azure File Share to this location proved problematic due to Linux permission issues. Although you can set it up, you won't be able to store or access apps successfully.

Documentation for deploying Budibase on Azure App Service (AAS) can be located at: <https://docs.budibase.com/docs/azure-app-service>

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


## Setup ACI and Azure Infrastructure using Terraform

