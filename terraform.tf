terraform {
  backend "azurerm" {
    storage_account_name = "pocjltenvstoragegithub"
    container_name       = "tfstate"
    # key                  = "poc.vml.tfstate"
    use_oidc = true
  }
} 
