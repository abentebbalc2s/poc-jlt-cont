provider "azurerm" {
  features {}
  # Replace with your Azure subscription ID
  subscription_id = var.subid
  # Optional: Choose the desired Azure environment from [AzureCloud, AzureChinaCloud, AzureUSGovernment, AzureGermanCloud]
  # environment = "AzureCloud"
  # Optional: Set the Azure tenant ID if using Azure Active Directory (AAD) service principal authentication
  tenant_id = var.tenantid
  # Optional: Set the client ID of your AAD service principal
  client_id = var.clientid
  # Optional: Set the client secret of your AAD service principal
  client_secret = var.clientsec
}

############################################################
# Environment pour Container Apps
############################################################

resource "azurerm_container_app_environment" "env" {
  name                       = "my-env2"
  location                   = var.rgloc
  resource_group_name        = var.rgname
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = "/subscriptions/88084eb2-a496-485d-9baa-95777f470424/resourceGroups/poc-jlt-env-container/providers/Microsoft.OperationalInsights/workspaces/poc-jlt-law"
}

data "azurerm_container_registry" "acr_login" {
  name                = "pocjltacr"
  resource_group_name = var.rgname
}
############################################################
# Managed Identity pour Container App
############################################################

resource "azurerm_user_assigned_identity" "uai" {
  name                = "jlt-poc-identity2"
  resource_group_name = var.rgname
  location            = var.rgloc
}

############################################################
# Role Assignment (AcrPull)
############################################################

resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/88084eb2-a496-485d-9baa-95777f470424/resourceGroups/poc-jlt-env-container/providers/Microsoft.ContainerRegistry/registries/pocjltacr"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id
}


# -------------------------

# Container App

# -------------------------

resource "azurerm_container_app" "app" {
  name                         = "mygrafana"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.rgname
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai.id]
  }
    registry {
    server   = data.azurerm_container_registry.acr_login.login_server
    identity = azurerm_user_assigned_identity.uai.id
  }

ingress {
  allow_insecure_connections = false
  external_enabled           = true
  target_port                = 3000

  traffic_weight {
    percentage      = 100
    latest_revision = true
  }
}

template {
  container {
    name   = "mygrafana"
    image  = "pocjltacr.azurecr.io/mygrafana:latest"
    cpu    = 0.25
    memory = "0.5Gi"

    readiness_probe {
      transport = "HTTP"
      port      = 3000
    }

    liveness_probe {
      transport = "HTTP"
      port      = 3000
    }

    startup_probe {
      transport = "HTTP"
      port      = 3000
    }
  }
}
}