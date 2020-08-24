// Resource group for the Azure VM and associated infrastructure
resource "azurerm_resource_group" "devops_rg" {
    name     = var.rg_name
    location = data.azurerm_resource_group.vnet_rg.location

    tags = {
        purpose = "DevOps Self-Hosted Agent"
    }
}

// REMOVE THIS FOR PRODUCTION DEPLOYMENT. DevOps Agent VM should be behind a firewall and should not have public ip. Used for testing purposes only.
resource "azurerm_public_ip" "devops_public_ip" {
    name                         = "${var.vm_name}PublicIP"
    location                     = azurerm_resource_group.devops_rg.location
    resource_group_name          = var.rg_name
    allocation_method            = "Dynamic"
}

// Network interface card for the Azure VM.
resource "azurerm_network_interface" "devops_vm_nic" {
    name                        = "${var.vm_name}nic"
    location                    = azurerm_resource_group.devops_rg.location
    resource_group_name         = var.rg_name

    ip_configuration {
        name                          = "${var.vm_name}NicConfig"
        subnet_id                     = data.azurerm_subnet.devops_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.devops_public_ip.id  // Remove this if no public ip is required.
    }

    tags = azurerm_resource_group.devops_rg.tags
}

// Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "devops_vm_nic" {
    network_interface_id      = azurerm_network_interface.devops_vm_nic.id
    network_security_group_id = data.azurerm_network_security_group.devops_nsg.id
}

// Azure VM to be used for hosting the Azure Pipelines agent
resource "azurerm_linux_virtual_machine" "devops_vm" {
    name                  = var.vm_name
    location              = azurerm_resource_group.devops_rg.location
    resource_group_name   = azurerm_resource_group.devops_rg.name
    network_interface_ids = [azurerm_network_interface.devops_vm_nic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "${var.vm_name}OsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = var.vm_name
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = var.ssh_pub_key
    }

    boot_diagnostics {
        storage_account_uri = data.azurerm_storage_account.devops_vm_stor.primary_blob_endpoint
    }

    custom_data    = base64encode("${data.template_file.linux-vm-cloud-init.rendered}")

    tags = azurerm_resource_group.devops_rg.tags
}

#Windows 

resource "azurerm_virtual_network" "azuredevopsnetwork_win" {
  name                = "AzureDevOpsVnet_Win"
  address_space       = ["10.200.0.0/16"]
  location            = data.azurerm_resource_group.vnet_rg.location
  resource_group_name = data.azurerm_resource_group.vnet_rg.name
}


# Create subnet
resource "azurerm_subnet" "azuredevopssubnet_win" {
  name                 = "AzureDevopsSubnet_Win"
  resource_group_name  = data.azurerm_resource_group.vnet_rg.name
  virtual_network_name = azurerm_virtual_network.azuredevopsnetwork_win.name
  address_prefixes       = ["10.200.2.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "azuredevopspublicip_win" {
  name                = "AzureDevOpsPublicIP_Win"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name
  allocation_method   = "Dynamic"
}

# Create network interface
resource "azurerm_network_interface" "azuredevopsnic_win" {
  name                      = "AzureDevOpsNIC_win"
  location                    = data.azurerm_resource_group.vnet_rg.location
  resource_group_name         = var.rg_name

  ip_configuration {
    name                          = "AzureDevOpsNicConfiguration_Win"
    subnet_id                     =  azurerm_subnet.azuredevopssubnet_win.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.azuredevopspublicip_win.id
  }

}

// Connect the security group to the win network interface
resource "azurerm_network_interface_security_group_association" "azuredevopsnic_win" {
    network_interface_id      = azurerm_network_interface.azuredevopsnic_win.id
    network_security_group_id = data.azurerm_network_security_group.devops_nsg.id
}



resource "azurerm_virtual_machine" "azuredevopsvm_win" {
  name                  = "AzureDevOps"
  location              = azurerm_resource_group.devops_rg.location
  resource_group_name   = azurerm_resource_group.devops_rg.name
  network_interface_ids = [azurerm_network_interface.azuredevopsnic_win.id]
  vm_size               = "Standard_DS1_v2"
  delete_os_disk_on_termination = "true"
  delete_data_disks_on_termination = "true"

  storage_os_disk {
    name              = "AzureDevOpsOsDiskWin"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = var.vm_name_win
    admin_username = "azureuser"
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true
  }

   boot_diagnostics {
        enabled = true
        storage_uri = data.azurerm_storage_account.devops_vm_stor.primary_blob_endpoint
   }
  
  tags = azurerm_resource_group.devops_rg.tags

}

# Custom script extension to install the DevOps agent
resource "azurerm_virtual_machine_extension" "azuredevopsvmex" {
  name                  = "AzureDevOpsAgent"
  virtual_machine_id    = azurerm_virtual_machine.azuredevopsvm_win.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  
  settings = <<SETTINGS
  {
  "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.windows-vm-init.rendered)}')) | Out-File -filepath install.ps1\" &&  powershell -ExecutionPolicy Unrestricted -File install.ps1 -URL ${var.devops_url} -PAT ${var.devops_win_pat} -POOL \"${var.devops_pool}\" -AGENT ${var.devops_win_agent_name}"
  }
SETTINGS
}
