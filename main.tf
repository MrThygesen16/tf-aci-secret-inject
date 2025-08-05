resource "azurerm_resource_group" "this" {
  name     = "rg-acg-example-01"
  location = "AustraliaEast"
}

resource "azurerm_container_group" "secure" {
  name                = "acg-windows-secure-01"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Windows"

  container {
    name   = "aci-win-01"
    image  = "mcr.microsoft.com/windows/servercore:ltsc2022"
    cpu    = "0.5"
    memory = "0.5"

    ports {
      port     = "22"
      protocol = "TCP"
    }

    ## let azapi inject these secrets
    # commands = []
    # environment_variables = {}
  }

  lifecycle {
    ignore_changes = [
      container[0].environment_variables,
      container[0].commands,
    ]
  }
}

resource "azapi_resource_action" "stop_container_group" {
  type        = "Microsoft.ContainerInstance/containerGroups@2023-05-01"
  resource_id = azurerm_container_group.secure.id
  action      = "stop"
  method      = "POST"
}

resource "azapi_update_resource" "inject_secrets" {
  type        = "Microsoft.ContainerInstance/containerGroups@2023-05-01"
  resource_id = azurerm_container_group.secure.id

  sensitive_body = {
    properties = {
      containers = [
        {
          name = azurerm_container_group.secure.container[0].name
          properties = {
            command = [
              "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
              "-Command",
              "Write-Output ('secure_var: ' + $env:secure_var); Write-Output ('non_secure_var: ' + $env:non_secure_var); Start-Sleep -Seconds 3600"
            ]

            environmentVariables = [
              {
                name  = "non_secure_var"
                value = "NonSecureValueHidden"
              },
              {
                name        = "secure_var"
                secureValue = "SecureValueHidden"
              }
            ]
          }
        }
      ]
    }
  }
}

resource "azapi_resource_action" "start_container_group" {
  type        = "Microsoft.ContainerInstance/containerGroups@2022-05-01"
  resource_id = azurerm_container_group.secure.id
  action      = "start"
  method      = "POST"

  depends_on = [azapi_update_resource.inject_secrets, azapi_resource_action.stop_container_group]
}


### Insecure Windows Container Group
resource "azurerm_container_group" "unsecure" {
  name                = "acg-windows-insecure-01"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Windows"

  container {
    name   = "aci-win-02"
    image  = "mcr.microsoft.com/windows/servercore:ltsc2022"
    cpu    = "0.5"
    memory = "0.5"

    ports {
      port     = "22"
      protocol = "TCP"
    }

    ## secrets added to state
    commands = [
      "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
      "-Command",
      "Write-Output ('secure_var: ' + $env:secure_var); Write-Output ('non_secure_var: ' + $env:non_secure_var); Start-Sleep -Seconds 3600"
    ]
    environment_variables = { "non_secure_var" = "NonSecureValue" }
    secure_environment_variables = { "secure_var" = "SecureValue" }
  }
}