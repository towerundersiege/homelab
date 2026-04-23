locals {
  jellyfin_public_hostname         = "jellyfin.towerundersiege.com"
  isambard_public_hostname         = "isambard.towerundersiege.com"
  isambard_browser_public_hostname = "isambard-browser.towerundersiege.com"
  tunnel_public_hostnames = [
    local.jellyfin_public_hostname,
    local.isambard_public_hostname,
    local.isambard_browser_public_hostname,
  ]
}

resource "cloudflare_ruleset" "jellyfin_geo_restriction" {
  count = var.cloudflare_enabled && (var.cloudflare_manage_zone_rules || var.cloudflare_manage_geo_restriction) ? 1 : 0

  zone_id     = var.cloudflare_zone_id
  name        = "Jellyfin geo restriction"
  description = "Restrict Jellyfin to UK client IPs"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    {
      ref         = "block_jellyfin_non_uk"
      description = "Block non-UK requests to Jellyfin"
      expression  = "(http.host eq \"${local.jellyfin_public_hostname}\" and ip.src.country ne \"GB\")"
      action      = "block"
      enabled     = true
    }
  ]
}

resource "cloudflare_ruleset" "jellyfin_cache_settings" {
  count = var.cloudflare_enabled && (var.cloudflare_manage_zone_rules || var.cloudflare_manage_cache_rule) ? 1 : 0

  zone_id     = var.cloudflare_zone_id
  name        = "default"
  description = ""
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = [
    {
      ref         = "db9ec0a7d00c413b9bd358d9c3077a27"
      description = "Jellyfin"
      expression  = "(http.host wildcard \"${local.jellyfin_public_hostname}\")"
      action      = "set_cache_settings"
      enabled     = true
      action_parameters = {
        cache = false
      }
    }
  ]
}

resource "cloudflare_ruleset" "jellyfin_auth_rate_limit" {
  count = var.cloudflare_enabled && (var.cloudflare_manage_zone_rules || var.cloudflare_manage_rate_limit) ? 1 : 0

  zone_id     = var.cloudflare_zone_id
  name        = "Jellyfin auth rate limiting"
  description = "Rate limit Jellyfin login attempts at Cloudflare"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    {
      ref         = "rate_limit_jellyfin_auth"
      description = "Rate limit Jellyfin login endpoint by source IP"
      expression  = "(http.host eq \"${local.jellyfin_public_hostname}\" and http.request.uri.path eq \"/Users/AuthenticateByName\")"
      action      = "block"
      enabled     = true
      action_parameters = {
        response = {
          status_code  = 429
          content_type = "application/json"
          content      = "{\"error\":\"rate_limited\"}"
        }
      }
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 10
        requests_per_period = 10
        mitigation_timeout  = 10
        requests_to_origin  = false
      }
    }
  ]
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "penzance_public_ingress" {
  count = var.cloudflare_enabled && var.cloudflare_tunnel_manage_config ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = var.cloudflare_tunnel_id

  config = {
    ingress = concat(
      [
        for hostname in local.tunnel_public_hostnames : {
          hostname = hostname
          service  = "https://caddy"
          origin_request = {
            no_tls_verify      = false
            origin_server_name = hostname
          }
        }
      ],
      [
        {
          service = "http_status:404"
        }
      ]
    )
    warp-routing = {
      enabled = true
    }
  }
}

resource "cloudflare_dns_record" "isambard_public" {
  zone_id = var.cloudflare_zone_id
  name    = "isambard"
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "isambard_browser_public" {
  zone_id = var.cloudflare_zone_id
  name    = "isambard-browser"
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "homelab_lan" {
  count = var.cloudflare_enabled ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = var.cloudflare_tunnel_id
  network    = var.cloudflare_private_network_cidr
  comment    = "Homelab LAN route for remote private access"
}

resource "cloudflare_zero_trust_access_application" "homelab_private_network" {
  count = var.cloudflare_enabled ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = "Homelab Private Network"
  type       = "self_hosted"
  destinations = [
    {
      cidr = var.cloudflare_private_network_cidr
      type = "private"
    }
  ]
  session_duration          = "24h"
  auto_redirect_to_identity = false

  policies = [
    for idx, email in var.cloudflare_zero_trust_email_allowlist : {
      name       = "Allow ${email}"
      precedence = idx + 1
      decision   = "allow"
      include = [
        {
          email = {
            email = email
          }
        }
      ]
    }
  ]
}

resource "cloudflare_zero_trust_device_custom_profile" "homelab_remote_access" {
  count = var.cloudflare_enabled && var.cloudflare_manage_warp_profile ? 1 : 0

  account_id  = var.cloudflare_account_id
  name        = "Homelab Remote Access"
  description = "Applies homelab private-network DNS behavior to approved operators"
  precedence  = 10
  enabled     = true
  match       = join(" or ", [for email in var.cloudflare_zero_trust_email_allowlist : "identity.email == \"${email}\""])

  service_mode_v2 = {
    mode = "warp"
  }
}

resource "cloudflare_zero_trust_device_custom_profile_local_domain_fallback" "homelab_internal_dns" {
  count = var.cloudflare_enabled && var.cloudflare_manage_warp_profile ? 1 : 0

  account_id = var.cloudflare_account_id
  policy_id  = cloudflare_zero_trust_device_custom_profile.homelab_remote_access[0].id

  domains = [
    for suffix in var.cloudflare_private_dns_suffixes : {
      suffix      = suffix
      description = "Resolve ${suffix} via homelab DNS"
      dns_server  = var.cloudflare_private_dns_servers
    }
  ]
}
