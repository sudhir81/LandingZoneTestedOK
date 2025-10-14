output "resource_groups" {
  value = {
    management = azurerm_resource_group.rg_mgmt.name
    network    = azurerm_resource_group.rg_net.name
    preprod    = azurerm_resource_group.rg_app.name
    security   = azurerm_resource_group.rg_sec.name
  }
}

output "vnet_ids" {
  value = {
    hub   = azurerm_virtual_network.vnet_hub.id
    spoke = azurerm_virtual_network.vnet_spoke.id
  }
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.law.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}
