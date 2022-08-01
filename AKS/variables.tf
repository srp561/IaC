variable "rg_name" {
  description = "Name of the resource group to be created"
  type        = string
  default     = "AzureKubernetes"
}
variable "location" {
  description = "Region in which to create the resources. Defaults to `West Europe`"
  type        = string
  default     = "westeurope"
}
variable "storage_account_name" {
  type        = string
  description = "Storage Account name in Azure"
  default     = "blobfilestorageacc342"
}

variable "storage_container_name" {
  type        = string
  description = "Storage Container name in Azure"
  default     = "blobstoragecontainer"
}
