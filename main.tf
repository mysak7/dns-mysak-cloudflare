terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "terraform_remote_state" "penny" {
  backend = "azurerm"
  config = {
    resource_group_name  = "azure-penny-tfstate-rg"
    storage_account_name = "azurepennytff04cd1"
    container_name       = "tfstate"
    key                  = "azure-penny.tfstate"
    use_azuread_auth     = true
  }
}


resource "azurerm_resource_group" "dns" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_dns_zone" "mysak_fun" {
  name                = "mysak.fun"
  resource_group_name = azurerm_resource_group.dns.name
}

resource "azurerm_dns_cname_record" "penny" {
  name                = "penny"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = data.terraform_remote_state.penny.outputs.container_app_fqdn
}

resource "azurerm_dns_a_record" "llm" {
  name                = "llm"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  records             = ["20.230.229.131"]
}

resource "azurerm_dns_cname_record" "grafana_llm" {
  name                = "grafana.llm"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = "llm.mysak.fun"
}

resource "azurerm_dns_txt_record" "penny_verification" {
  name                = "asuid.penny"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record {
    value = "24C4FD8D3A8507E43D386A411379665BC15579939C271A26E15AE5643A8A540A"
  }
}

resource "azurerm_dns_cname_record" "cloudfire" {
  name                = "cloudfire"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = "mi-3-cloudfire-y29hf3.azurewebsites.net"
}

resource "azurerm_dns_txt_record" "cloudfire_verification" {
  name                = "asuid.cloudfire"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record {
    value = "24C4FD8D3A8507E43D386A411379665BC15579939C271A26E15AE5643A8A540A"
  }
}

output "nameservers" {
  value       = azurerm_dns_zone.mysak_fun.name_servers
  description = "Nameservery ke zkopírování do WEDOS"
}
