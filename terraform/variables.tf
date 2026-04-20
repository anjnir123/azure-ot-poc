variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-ot-poc-dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "iot_hub_name" {
  description = "Name of the Azure IoT Hub"
  type        = string
  default     = "iothub-crescent-ot-poc"
}

# IMPORTANT: Storage account names must be globally unique, all lowercase, 3-24 chars
# If this name is taken, change the last 4 digits to something random
variable "storage_account_name" {
  description = "Globally unique storage account name"
  type        = string
  default     = "otprojectans1234"
}

# IMPORTANT: Key Vault name must be globally unique, 3-24 chars
variable "key_vault_name" {
  description = "Globally unique Key Vault name"
  type        = string
  default     = "ot-project-ans05"
}

variable "stream_analytics_job_name" {
  description = "Name of the Stream Analytics job"
  type        = string
  default     = "sa-crescent-ot-poc"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "OT-POC"
    ManagedBy   = "Terraform"
    Owner       = "Anjali"
  }
}
