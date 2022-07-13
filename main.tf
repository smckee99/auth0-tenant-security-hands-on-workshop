variable "auth0_domain" {}
variable "auth0_client_id" {}
variable "auth0_client_secret" {}
variable "auth0_admin_user_password" {}
variable "auth0_application_callback" {}

variable "terraform-express-api-identifier" {
  type    = string
  default = "https://terraform-express-resource-server"
}

// This password is intentionally put here, since it is already exposed in a data breach.
// This is the same password example used in the Breached Password Detection documentation.
// https://auth0.com/docs/secure/attack-protection/breached-password-detection#verify-detection-configuration
variable "auth0_breached_password" { 
    type = string
    default = "Paaf213XXYYZZ"
}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
    auth0 = {
      source = "auth0/auth0"
      version = "0.29.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "terraform-secure-express" {
  name = "terraform-secure-express:1.0"
  build {
    path = "."
    tag  = ["terraform-secure-express:1.0"]
  }
}

resource "docker_container" "terraform-secure-express" {
  image = docker_image.terraform-secure-express.latest
  name  = "terraform-secure-express"
  ports {
    internal = 3000
    external = 3000
  }
  env = [
    "AUTH0_CLIENT_ID=${auth0_client.terraform-secure-express.client_id}",
    "AUTH0_CLIENT_SECRET=${auth0_client.terraform-secure-express.client_secret}",
    "AUTH0_CLIENT_DOMAIN=${var.auth0_domain}",
    "AUTH0_API_IDENTIFIER=${var.terraform-express-api-identifier}",
    "AUTH0_CALLBACK_URL=${var.auth0_application_callback}"
  ]
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
}

resource "auth0_tenant" "tenant" {
    flags {
        enable_client_connections = false
    }
}

resource "auth0_attack_protection" "attack_protection" {
  suspicious_ip_throttling {
    enabled   = true
    shields   = ["admin_notification", "block"]
    // allowlist = ["192.168.1.1"]
    pre_login {
      max_attempts = 3 // block after 3 failed logins
      rate         = 34560 // grant new attempt every 35 seconds (milliseconds)
    }
    pre_user_registration {
      max_attempts = 2 // block signups after 2 failed attempts
      rate         = 30000 // grant new attempt every 30 seconds (milliseconds)
    }
  }
  brute_force_protection { // safeguards against a single IP address attacking a single user account.
    allowlist    = ["127.0.0.1"]
    enabled      = true
    max_attempts = 2
    mode         = "count_per_identifier_and_ip"
    shields      = ["block", "user_notification"]
  }
  breached_password_detection {
    admin_notification_frequency = ["immediately"]
    enabled                      = true
    method                       = "standard"
    shields                      = ["admin_notification", "block"]
  }
}


resource "auth0_client" "terraform-secure-express" {
  name                = "Terraform Secure Express"
  description         = "App for running Dockerized Express application via Terraform"
  app_type            = "regular_web"
  callbacks           = [FILL]
  allowed_logout_urls = [var.auth0_application_callback]
  oidc_conformant     = true
  is_first_party      = true

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_connection" "terraform-express-user-db" {
  name     = "terraform-express-user-db"
  strategy = "auth0"
  options {
    password_policy        = "good"
    password_dictionary {
      enable = true
      dictionary = ["Password1!", "your-company-name", "other-relevant-names", "etc"]
    }
    brute_force_protection = true
    non_persistent_attrs = ["name", "given_name", "family_name", "phone_number"]
  }
  enabled_clients = [auth0_client.terraform-secure-express.id, var.auth0_client_id]
}


resource "auth0_user" "terraform-express-admin-user" {
  connection_name = auth0_connection.terraform-express-user-db.name
  email           = "admin@example.com"
  email_verified  = true
  password        = var.auth0_admin_user_password
  roles           = [auth0_role.terraform-express-admin-role.id]
}

resource "auth0_user" "terraform-express-brute-force-user" {
  connection_name = auth0_connection.terraform-express-user-db.name
  email           = "bruteforce-test@example.com"
  email_verified  = true
  password        = var.auth0_admin_user_password
}

resource "auth0_user" "terraform-express-breached-password-user" {
  connection_name = auth0_connection.terraform-express-user-db.name
  email           = "leak-test@example.com"
  email_verified  = true
  password        = var.auth0_breached_password
}

resource "auth0_guardian" "default" {
    policy = "confidence-score" // means the trigger of MFA will be adaptive
    otp = true
    email = true
}

resource "auth0_resource_server" "terraform-express-resource-server" {
  name                                            = "Terraform Auth0 Resource Server"
  identifier                                      = var.terraform-express-api-identifier
  skip_consent_for_verifiable_first_party_clients = true
  token_dialect                                   = "access_token_authz"
  enforce_policies                                = true

  scopes {
    value       = "create:note"
    description = "Only administrators can create notes"
  }

  scopes {
    value       = "read:note:self"
    description = "Read Own Notes"
  }

  scopes {
    value       = "read:note:all"
    description = "Administrators can read all notes"
  }
}

resource "auth0_role" "terraform-express-admin-role" {
  name        = "admin"
  description = "administrator"
  permissions {
    resource_server_identifier = auth0_resource_server.terraform-express-resource-server.identifier
    name                       = "create:note"
  }

  permissions {
    resource_server_identifier = auth0_resource_server.terraform-express-resource-server.identifier
    name                       = "read:note:all"
  }
}

resource "auth0_role" "terraform-express-basic-user-role" {
  name        = "basic_user"
  description = "Basic User"
  permissions {
    resource_server_identifier = auth0_resource_server.terraform-express-resource-server.identifier
    name                       = "read:note:self"
  }
}

resource "auth0_rule" "terraform-express-basic_user-rule" {
  name = "basic-user-role-assignment"
  script = templatefile("${path.module}/basic-user-rule.js", {
    TERRAFORM_ROLE_ID : auth0_role.terraform-express-basic-user-role.id
  })
  enabled = true
}