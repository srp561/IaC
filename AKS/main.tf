resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}
resource "azurerm_virtual_network" "aksvnet" {
  name                = "Vnet-AzureKubernetes"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}
resource "azurerm_subnet" "akssub" {
  name                 = "akssubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.1.0.0/24"]
}
# Create a Subnet 
resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.1.2.0/24"]
}
resource "azurerm_log_analytics_workspace" "logworkspace" {
  name                = "k8s-workspace-${random_id.workspace.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}
resource "azurerm_log_analytics_solution" "logsolution" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.logworkspace.id
  workspace_name        = azurerm_log_analytics_workspace.logworkspace.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}
resource "azurerm_kubernetes_cluster" "azks" {
  name                = "BPMSuite-AKSCluster"
  #kubernetes_version  = "1.20.9"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "bpmaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2ads_v5"
    enable_node_public_ip = false
    enable_auto_scaling   = false
    os_disk_size_gb = 30
    vnet_subnet_id = azurerm_subnet.akssub.id
  }
  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
    network_policy     = "calico"
  }
  addon_profile {
        oms_agent {
            enabled = true
            log_analytics_workspace_id = "${azurerm_log_analytics_workspace.logworkspace.id}"
        }
    }
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Test"
  }
}
resource "azurerm_container_registry" "azcr" {
  name                = "containerregistry56587"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                      = "Standard"
  admin_enabled            = false
}
resource "azurerm_role_assignment" "aksintegration" {
  principal_id                     = azurerm_kubernetes_cluster.azks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.azcr.id
  skip_service_principal_aad_check = true
}

resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private" # "blob" "private"
}

resource "azurerm_storage_blob" "blob" {
  name                  = "blobstorage.zip"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  type                   = "Block"
}
resource "azurerm_storage_share" "fileshare" {
  name                 = "azurefileshare"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 50
}
resource "azurerm_redis_cache" "rediscache" {
  name                = "azrediscache"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  capacity            = 2
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
  }
}
resource "azurerm_public_ip" "examplepubip" {
  name                = "example-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.aksvnet.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.aksvnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.aksvnet.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.aksvnet.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.aksvnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.aksvnet.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.aksvnet.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "example-appgateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.examplepubip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

data "azurerm_kubernetes_cluster" "credentials" {
  name                = azurerm_kubernetes_cluster.azks.name
  resource_group_name = azurerm_resource_group.rg.name
}
provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
  }
}
# testing only for helm installaton 
#resource "helm_release" "nginx_ingress" {
#  name       = "nginx-ingress-controller"

 # repository = "https://charts.bitnami.com/bitnami"
 # chart      = "nginx-ingress-controller"

  #set {
   # name  = "service.type"
    #value = "ClusterIP"
  #}
#}

resource "azurerm_dns_zone" "dnszone" {
  name                = "azure.co.in"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_dns_a_record" "dnsrecord" {
  name                = "appgatewaypubadd"
  zone_name           = azurerm_dns_zone.dnszone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.examplepubip.id
}
