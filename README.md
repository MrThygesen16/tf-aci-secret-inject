# tf-aci-secret-inject

This is a sample repo that shows how to use a combination of Azurerm and AzAPI providers to safely inject secrets into an Azure Container Instance.


```hcl
resource "azapi_update_resource" "inject_secrets" {
  type        = "Microsoft.ContainerInstance/containerGroups@2023-05-01"
  resource_id = azurerm_container_group.this.id

  sensitive_body = {
    properties = {
      containers = [
        {
          name = azurerm_container_group.this.container[0].name
          properties = {
            command = [
              "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
              "-Command",
              "Write-Output ('secure_var: ' + $env:secure_var); Write-Output ('non_secure_var: ' + $env:non_secure_var); Start-Sleep -Seconds 3600"
            ]

            environmentVariables = [
              {
                name  = "non_secure_var"
                value = "VisibleNonSecureValue"
              },
              {
                name        = "secure_var"
                secureValue = "SecureValueNotWrittenToTerraformState"
              }
            ]
          }
        }
      ]
    }
  }
}

```

TODO