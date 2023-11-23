# Grupo de Recursos
resource "azurerm_resource_group" "iac-gs" {
  name     = "iac-gs"
  location = "East US"
}

# Criação da Rede Virtual e Subnet
resource "azurerm_virtual_network" "gs-vnet" {
  name                = "gs-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"
  resource_group_name = azurerm_resource_group.iac-gs.name
}

resource "azurerm_subnet" "gs-subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.iac-gs.name
  virtual_network_name = azurerm_virtual_network.gs-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Criação das Interfaces de Rede
resource "azurerm_network_interface" "vm-nic" {
  count                     = 2
  name                      = "vm-nic-${count.index}"
  location                  = "East US"
  resource_group_name       = azurerm_resource_group.iac-gs.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.gs-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Criação das VMs
resource "azurerm_linux_virtual_machine" "vm" {
  count                            = 2
  name                             = "Apache${count.index}"
  location                         = "East US"
  resource_group_name              = azurerm_resource_group.iac-gs.name
  network_interface_ids            = [azurerm_network_interface.vm-nic[count.index].id]
  size                             = "Standard_DS1_v2"
  admin_username                   = "thiago"
  admin_password                   = "Password1234!"
  disable_password_authentication  = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }
}

# Script de inicialização para instalar Apache e configurar a página HTML
resource "azurerm_virtual_machine_extension" "customScript" {
  count                = 2
  name                 = "hostname-${count.index}"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "sudo apt-get update && sudo apt-get install -y apache2 && echo 'Amém irmãos, deu certo!!!' > /var/www/html/index.html"
    }
SETTINGS
}

# Configuração do Load Balancer
resource "azurerm_lb" "gs-lb" {
  name                = "GSLoadBalancer"
  location            = "East US"
  resource_group_name = azurerm_resource_group.iac-gs.name

  frontend_ip_configuration {
    name = "publicIPAddress"
  }
}

resource "azurerm_lb_backend_address_pool" "gs_back" {
  loadbalancer_id = azurerm_lb.gs-lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "gs_lb_probe" {
  resource_group_name = azurerm_resource_group.iac-gs.name
  loadbalancer_id     = azurerm_lb.gs-lb.id
  name                = "HealthProbe"
  protocol            = "Http"
  request_path        = "/"
  port                = 80
}

resource "azurerm_lb_rule" "main" {
  resource_group_name            = azurerm_resource_group.iac-gs.name
  loadbalancer_id                = azurerm_lb.gs-lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.gs_back.id
  probe_id                       = azurerm_lb_probe.gs_lb_probe.id
}
