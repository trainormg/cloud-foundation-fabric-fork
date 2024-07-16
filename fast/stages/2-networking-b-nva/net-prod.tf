/**
 * Copyright 2023 Google LLC
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

# tfdoc:file:description Production spoke VPC and related resources.

module "prod-spoke-project" {
  source          = "../../../modules/project"
  billing_account = var.billing_account.id
  name            = "prod-net-spoke-0"
  parent          = module.folder.id
  prefix          = var.prefix
  services = concat([
    "container.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "iap.googleapis.com",
    "networkmanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "stackdriver.googleapis.com",
    "vpcaccess.googleapis.com"
    ],
    (
      var.fast_features.gcve
      ? ["vmwareengine.googleapis.com"]
      : []
    )
  )
  shared_vpc_host_config = {
    enabled = true
  }
  metric_scopes = [module.landing-project.project_id]
  iam = {
    for k, v in var.iam_config.iam.prod : k => compact([
      strcontains(k, ":")
      ? k
      : lookup(local.service_accounts, k, "")
    ])
  }
  # allow specific service accounts to assign a set of roles
  iam_bindings = {
    sa_delegated_grants = {
      role = "roles/resourcemanager.projectIamAdmin"
      members = compact([
        for k in var.iam_config.delegated_grants.principals_prod :
        strcontains(k, ":")
        ? k
        : lookup(local.service_accounts, k, "")
      ])
      condition = {
        title       = "stage3_sa_delegated_grants"
        description = "Stage 3 service accounts delegated grants."
        expression = format(
          "api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', []).hasOnly([%s])",
          join(",", formatlist("'%s'", var.iam_config.delegated_grants.roles))
        )
      }
    }
  }
  tag_bindings = (
    lookup(var.tag_values, "fast-environment/prod", null) == null
    ? {}
    : {
      environment = var.tag_values["fast-environment/prod"]
    }
  )
}

module "prod-spoke-vpc" {
  source     = "../../../modules/net-vpc"
  project_id = module.prod-spoke-project.project_id
  name       = "prod-spoke-0"
  mtu        = 1500
  dns_policy = {
    logging = var.dns.enable_logging
  }
  factories_config = {
    subnets_folder = "${var.factories_config.data_dir}/subnets/prod"
  }
  delete_default_routes_on_create = true
  psa_configs                     = var.psa_ranges.prod
  # Set explicit routes for googleapis; send everything else to NVAs
  create_googleapis_routes = {
    private    = true
    restricted = true
  }
  routes = var.enable_ncc_ra ? null : {
    nva-primary-to-primary = {
      dest_range    = "0.0.0.0/0"
      priority      = 1000
      tags          = [local.region_shortnames[var.regions.primary]]
      next_hop_type = "ilb"
      next_hop      = module.ilb-nva-landing["primary"].forwarding_rule_addresses[""]
    }
    nva-secondary-to-secondary = {
      dest_range    = "0.0.0.0/0"
      priority      = 1000
      tags          = [local.region_shortnames[var.regions.secondary]]
      next_hop_type = "ilb"
      next_hop      = module.ilb-nva-landing["secondary"].forwarding_rule_addresses[""]
    }
    nva-primary-to-secondary = {
      dest_range    = "0.0.0.0/0"
      priority      = 1001
      tags          = [local.region_shortnames[var.regions.primary]]
      next_hop_type = "ilb"
      next_hop      = module.ilb-nva-landing["secondary"].forwarding_rule_addresses[""]
    }
    nva-secondary-to-primary = {
      dest_range    = "0.0.0.0/0"
      priority      = 1001
      tags          = [local.region_shortnames[var.regions.secondary]]
      next_hop_type = "ilb"
      next_hop      = module.ilb-nva-landing["primary"].forwarding_rule_addresses[""]
    }
  }
}

module "prod-spoke-firewall" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = module.prod-spoke-project.project_id
  network    = module.prod-spoke-vpc.name
  default_rules_config = {
    disabled = true
  }
  factories_config = {
    cidr_tpl_file = "${var.factories_config.data_dir}/cidrs.yaml"
    rules_folder  = "${var.factories_config.data_dir}/firewall-rules/prod"
  }
}

module "peering-prod" {
  source        = "../../../modules/net-vpc-peering"
  prefix        = "prod-peering-0"
  local_network = module.prod-spoke-vpc.self_link
  peer_network  = module.landing-vpc.self_link
}
