terraform {
  backend "azurerm" {
    resource_group_name      = "RG-DEMO-TF"
    storage_account_name     = "storageaccountdemostf"
    container_name           = "terraform"
    key                      = "terraform.tfstate"
  }
}
