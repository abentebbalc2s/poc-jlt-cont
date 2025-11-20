/*
terraform {
  backend "azurerm" {
    resource_group_name  = "poc-jlt-env-container"
    storage_account_name = "pocjltenvstoragegithub"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
required_providers {
  azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.53.0"
    }
  }
}

*/
provider "azurerm" {
  features {}
}
############################################################
# Environment pour Container Apps
############################################################

resource "azurerm_container_app_environment" "env" {
  name                       = "my-env2"
  location                   = "West Europe"
  resource_group_name        = "poc-jlt-env-container"
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = "/subscriptions/88084eb2-a496-485d-9baa-95777f470424/resourceGroups/poc-jlt-env-container/providers/Microsoft.OperationalInsights/workspaces/poc-jlt-law"
}

data "azurerm_container_registry" "acr_login" {
  name                = "pocjltacr"
  resource_group_name = "poc-jlt-env-container"
}
############################################################
# Managed Identity pour Container App
############################################################

resource "azurerm_user_assigned_identity" "uai" {
  name                = "jlt-poc-identity2"
  resource_group_name = "poc-jlt-env-container"
  location            = "West Europe"
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
  resource_group_name          = "poc-jlt-env-container"
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





