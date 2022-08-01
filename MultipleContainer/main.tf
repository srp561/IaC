locals {
  resource_group_name="app-grp"
  location="North Europe"
}
  resource "azurerm_resource_group" "appgrp" {
  name     = local.resource_group_name
  location = local.location  
}

resource "azurerm_storage_account" "appstore566565637" {  
  name                     = "appstore566565637"
  resource_group_name      = "app-grp"
  location                 = "North Europe"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind = "StorageV2"
  depends_on = [
    azurerm_resource_group.appgrp
  ]
}

resource "azurerm_storage_container" "data" {
  count =3
  name                  = "data${count.index}"
  storage_account_name  = "appstore566565637"
  container_access_type = "blob"
  depends_on = [
    azurerm_storage_account.appstore566565637
  ]
}
