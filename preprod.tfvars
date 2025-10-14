subscription_id = "4c13f2a5-9a74-4ad1-b6a6-f99adc18cb3b"
location        = "East US"

tags = {
  environment = "preprod"
  owner       = "appdevop-team"
  workload    = "landing-zone"
  cost_center = "IND-1234"
}

rg_names = {
  management = "rg-preprod-mgmt"
  network    = "rg-preprod-net"
  preprod    = "rg-preprod-app"
  security   = "rg-preprod-sec"
}

law_name           = "log-preprod-central"
law_retention_days = 30

central_storage_account_name = "jumbopreprod14598"

hub_vnet_name     = "vnet-preprod-hub"
hub_address_space = ["10.0.0.0/16"]
hub_subnets = {
  AzureFirewallSubnet = { address_prefix = "10.0.0.0/26" }
  GatewaySubnet       = { address_prefix = "10.0.0.64/26" }
  shared-services     = { address_prefix = "10.0.1.0/24" }
}

preprod_vnet_name     = "vnet-preprod-spoke"
preprod_address_space = ["10.10.0.0/16"]
preprod_subnets = {
  app  = { address_prefix = "10.10.1.0/24" }
  data = { address_prefix = "10.10.2.0/24" }
}

enable_bastion        = true
bastion_subnet_prefix = "10.0.2.0/27"

preprod_kv_name = "kv-preprod-shared"
kv_rbac_enabled = true

allowed_locations                      = ["East US", "West US", "Central US"]
enforce_policies                       = false
custom_allowed_locations_definition_id = "/subscriptions/4c13f2a5-9a74-4ad1-b6a6-f99adc18cb3b/providers/Microsoft.Authorization/policyDefinitions/168c51a6652d442f85440758"

reader_object_ids      = []
contributor_object_ids = []
