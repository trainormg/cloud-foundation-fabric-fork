/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# tfdoc:file:description Landing DNS zones and peerings setup.

module "dns-fwd-onprem" {
  source     = "../../../modules/dns"
  project_id = module.net-project.project_id
  name       = "example-com"
  zone_config = {
    domain = "onprem.example.com."
    forwarding = {
      client_networks = [
        module.external-vpc.self_link,
        module.shared-vpc.self_link
      ]
      forwarders = { for ip in var.dns.onprem : ip => null }
    }
  }
}

# module "dns-fwd-onprem-rev-10" {
#   source     = "../../../modules/dns"
#   project_id = module.net-project.project_id
#   name       = "root-reverse-10"
#   zone_config = {
#     domain = "10.in-addr.arpa."
#     forwarding = {
#       client_networks = [
#         module.external-vpc.self_link,
#       ]
#       forwarders = { for ip in var.dns.onprem : ip => null }
#     }
#   }
# }

module "dns-priv-gcp" {
  source     = "../../../modules/dns"
  project_id = module.net-project.project_id
  name       = "gcp-example-com"
  zone_config = {
    domain = "gcp.example.com."
    private = {
      client_networks = [
        module.external-vpc.self_link,
        module.shared-vpc.self_link
      ]
    }
  }
  recordsets = {
    "A localhost" = { records = ["127.0.0.1"] }
  }
}

module "dns-policy-googleapis" {
  source     = "../../../modules/dns-response-policy"
  project_id = module.net-project.project_id
  name       = "googleapis"
  networks = {
    shared   = module.shared-vpc.self_link
    external = module.external-vpc.self_link
  }
  rules_file = var.factories_config.dns_policy_rules_file
}