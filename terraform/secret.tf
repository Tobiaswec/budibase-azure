// -------------- DOCKER REGISTRY SECRET --------------
data "azurerm_key_vault_secret" "docker-registry-token" {
  name         = "docker-registry-token"
  key_vault_id = azurerm_key_vault.company-key-vault.id
}