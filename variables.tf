variable "resource_group_name" {
  type    = string
  default = "rg-dns-mysak-fun"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
  description = "Cloudflare API token with Zone:DNS:Edit and Zone:Zone:Read permissions for mysak.fun"
}

variable "azure_seip_nginx_ip" {
  type        = string
  default     = "20.103.44.124"
  description = "nginx-ingress LoadBalancer IP from azure-seip cluster (terraform output nginx_ingress_ip)"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID (Zero Trust dashboard → Settings → Account ID)"
}

variable "entra_seip_client_id" {
  type        = string
  description = "App Registration client ID for seip.mysak.fun Cloudflare Access"
}

variable "entra_seip_client_secret" {
  type      = string
  sensitive = true
  description = "App Registration client secret for seip.mysak.fun Cloudflare Access"
}

variable "aws_penny_alb_dns" {
  type        = string
  default     = "alb-prd-euc1-penny-279184951.eu-central-1.elb.amazonaws.com"
  description = "DNS name of the aws-penny ALB (terraform output alb_dns_name in aws-penny/terraform)"
}
