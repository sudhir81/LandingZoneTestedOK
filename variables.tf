############################
# Core
############################
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "East US"
}

############################
# Tags
############################
variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    environment = "preprod"
    owner       = "appdevop-team"
    workload    = "landing-zone"
    cost_center = "IND-1234"
  }
}

############################
# Resource Groups
############################
variable "rg_names" {
  description = "Resource group names"
  type = object({
    management = string
    network    = string
    preprod    = string
    security   = string
  })
  default = {
    management = "rg-preprod-mgmt"
    network    = "rg-preprod-net"
    preprod    = "rg-preprod-app"
    security   = "rg-preprod-sec"
  }
}

############################
# Log Analytics
############################
variable "law_name" {
  description = "Log Analytics workspace name"
  type        = string
  default     = "log-preprod-central"
}

variable "law_retention_days" {
  description = "Retention (days)"
  type        = number
  default     = 30
}

############################
# Storage
############################
variable "central_storage_account_name" {
  description = "Globally unique storage account name (3-24 lowercase letters/numbers)"
  type        = string
  default     = "0jum8ecs6erd196d"
}

############################
# Networking
############################
variable "hub_vnet_name" {
  type    = string
  default = "vnet-preprod-hub"
}
variable "hub_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}
variable "hub_subnets" {
  type = map(object({
    address_prefix = string
  }))
  default = {
    AzureFirewallSubnet = { address_prefix = "10.0.0.0/26" }
    GatewaySubnet       = { address_prefix = "10.0.0.64/26" }
    shared-services     = { address_prefix = "10.0.1.0/24" }
  }
}

variable "preprod_vnet_name" {
  type    = string
  default = "vnet-preprod-spoke"
}
variable "preprod_address_space" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}
variable "preprod_subnets" {
  type = map(object({
    address_prefix = string
  }))
  default = {
    app  = { address_prefix = "10.10.1.0/24" }
    data = { address_prefix = "10.10.2.0/24" }
  }
}

variable "enable_bastion" {
  type    = bool
  default = true
}
variable "bastion_subnet_prefix" {
  type    = string
  default = "10.0.2.0/27"
}

############################
# Key Vault
############################
variable "preprod_kv_name" {
  type    = string
  default = "kv-preprod-shared"
}

variable "kv_rbac_enabled" {
  type    = bool
  default = true
}

# Optional access policy subjects (only used if kv_rbac_enabled = false)
variable "kv_reader_object_ids" {
  type    = list(string)
  default = []
}
variable "kv_secrets_officer_object_ids" {
  type    = list(string)
  default = []
}

############################
# Governance Policies
############################
variable "allowed_locations" {
  type    = list(string)
  default = ["East US", "West US", "Central US"]
}
variable "enforce_policies" {
  type    = bool
  default = false
}
variable "custom_allowed_locations_definition_id" {
  description = "Optional custom policy definition ID for allowed locations. If empty, no assignment is created here."
  type        = string
  default     = "/subscriptions/1c95c3eb-55ac-4d47-bee1-e823c941e413/providers/Microsoft.Authorization/policyDefinitions/168c51a6652d442f85440758"
}

############################
# Optional RBAC on RGs
############################
variable "reader_object_ids" {
  description = "Optional AAD object IDs to grant Reader on preprod RG"
  type        = list(string)
  default     = []
}
variable "contributor_object_ids" {
  description = "Optional AAD object IDs to grant Contributor on preprod RG"
  type        = list(string)
  default     = []
}
