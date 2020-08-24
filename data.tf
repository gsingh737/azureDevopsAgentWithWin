data "azurerm_resource_group" "vnet_rg" {
  name = var.vnet_rg_name
}

data "azurerm_virtual_network" "devops_vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_rg_name
}

data "azurerm_subnet" "devops_subnet" {
  name                 = var.vnet_subnet_name
  virtual_network_name = data.azurerm_virtual_network.devops_vnet.name
  resource_group_name  = var.vnet_rg_name
}

data "azurerm_network_security_group" "devops_nsg" {
  name                = var.vnet_nsg_name
  resource_group_name = var.vnet_rg_name
}

data "azurerm_storage_account" "devops_vm_stor" {
  name                = var.diag_store_name
  resource_group_name = var.diag_store_rg
}

# Data template Bash bootstrapping file
data "template_file" "linux-vm-cloud-init" {
  template = file(var.cloud_init_file)

  vars = {
    devops_url = var.devops_url
    devops_pat = var.devops_pat
    devops_agent_name = var.devops_agent_name
    devops_pool = var.devops_pool
  }
}

data "template_file" "windows-vm-init" {
    template = file(var.windows_init_file)
} 
