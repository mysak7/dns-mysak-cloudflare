terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "dns" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_dns_zone" "mysak_fun" {
  name                = "mysak.fun"
  resource_group_name = azurerm_resource_group.dns.name
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

# docs and aws_penny Azure DNS resources removed — DNS is now authoritative in Cloudflare,
# not Azure DNS. Manage those records directly in Cloudflare dashboard or add cloudflare_record
# resources below when the correct remote state output names are known.

output "nameservers" {
  value       = azurerm_dns_zone.mysak_fun.name_servers
  description = "Nameservery ke zkopírování do WEDOS"
}

# ── Cloudflare ────────────────────────────────────────────────────────────────

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "mysak_fun" {
  name = "mysak.fun"
}

resource "cloudflare_record" "azure_seip" {
  zone_id = data.cloudflare_zone.mysak_fun.id
  name    = "azure-seip"
  content = var.azure_seip_nginx_ip
  type    = "A"
  ttl     = 1 # 1 = automatic (required when proxied)
  proxied = true
}

# ---------------------------------------------------------------------------
# seip.mysak.fun — AWS seip-portal behind Cloudflare Access (Entra ID)
# ---------------------------------------------------------------------------

# Read the Elastic IP created in the seip-infrastructure dev environment
data "aws_eip" "nat_bastion" {
  tags = {
    Name = "dev-nat-bastion-eip"
  }
}

resource "cloudflare_record" "seip" {
  zone_id = data.cloudflare_zone.mysak_fun.id
  name    = "seip"
  content = data.aws_eip.nat_bastion.public_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Cloudflare Access — Entra ID identity provider
# Before applying: create a new App Registration in Azure portal:
#   Redirect URI: https://<your-team>.cloudflareaccess.com/cdn-cgi/access/callback
#   Note the Application (client) ID and create a client secret.
resource "cloudflare_access_identity_provider" "entra_id" {
  account_id = var.cloudflare_account_id
  name       = "Entra ID"
  type       = "azureAD"

  config {
    client_id      = var.entra_seip_client_id
    client_secret  = var.entra_seip_client_secret
    directory_id   = "f50acfeb-1d10-42e2-80af-2f0ca0a0d6a0"
    support_groups = true
  }
}

# Application — protects the entire seip.mysak.fun domain
resource "cloudflare_access_application" "seip" {
  account_id                = var.cloudflare_account_id
  name                      = "SEIP Portal"
  domain                    = "seip.mysak.fun"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [cloudflare_access_identity_provider.entra_id.id]
}

# Policy — allow only michal.burdik@gmail.com
resource "cloudflare_access_policy" "seip_allow" {
  application_id = cloudflare_access_application.seip.id
  account_id     = var.cloudflare_account_id
  name           = "Allow michal.burdik@gmail.com"
  precedence     = 1
  decision       = "allow"

  include {
    email = ["michal.burdik@gmail.com"]
  }
}

# ---------------------------------------------------------------------------
# aws-penny.mysak.fun — AWS ECS Fargate app behind Cloudflare proxy
# ALB speaks HTTP only; Configuration Rule overrides SSL to "flexible" so
# Cloudflare connects to origin over HTTP while serving HTTPS to the user.
# ---------------------------------------------------------------------------

resource "cloudflare_record" "aws_penny" {
  zone_id = data.cloudflare_zone.mysak_fun.id
  name    = "aws-penny"
  content = var.aws_penny_alb_dns
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_ruleset" "ssl_flexible_aws_penny" {
  zone_id     = data.cloudflare_zone.mysak_fun.id
  name        = "SSL flexible for aws-penny"
  description = "Override SSL to flexible for aws-penny (ALB HTTP-only origin)"
  kind        = "zone"
  phase       = "http_config_settings"

  rules {
    action = "set_config"
    action_parameters {
      ssl = "flexible"
    }
    expression  = "(http.host eq \"aws-penny.mysak.fun\")"
    description = "aws-penny ALB is HTTP only"
    enabled     = true
  }
}

resource "cloudflare_zone_settings_override" "mysak_fun" {
  zone_id = data.cloudflare_zone.mysak_fun.id
  settings {
    ssl = "full" # origin has valid Let's Encrypt cert; use "strict" to also verify chain
  }
}
