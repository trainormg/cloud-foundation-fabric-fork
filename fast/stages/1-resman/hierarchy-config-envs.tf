/**
 * Copyright 2024 Google LLC
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

# tfdoc:file:description Transformations for environment-based hierarchy groups.

locals {
  # compute list of folders for groups with environments
  _hg_folders_env = flatten([
    for k, v in local.hierarchy_groups : [
      for key in v.config.environments : {
        hg     = k
        key    = "${k}-${key}"
        name   = var.environments[key]
        parent = k
      } if lookup(var.environments, key, null) != null
    ]
  ])
  # compute list of billing IAM for environment SAs
  _hg_iam_billing_env = flatten([
    for k, v in local.hierarchy_groups : concat(
      [
        for member in v.fast_config.billing_iam.cost_manager_principals : [
          for key in v.config.environments : [{
            hg     = "${k}-${key}"
            key    = "${k}-${key}/cost_manager/${member}"
            role   = "roles/billing.costsManager"
            member = member
          }]
        ] if v._has.automation == true && startswith(member, "sa-r")
      ],
      [
        for member in v.fast_config.billing_iam.user_principals : [
          for key in v.config.environments : [{
            hg     = "${k}-${key}"
            key    = "${k}-${key}/user/${member}"
            role   = "roles/billing.user"
            member = member
          }]
        ] if v._has.automation == true && startswith(member, "sa-r")
      ]
    ) if v._has.envs
  ])
  # compute list of org-level IAM for environment SAs
  _hg_iam_org_env = flatten([
    for k, v in local.hierarchy_groups : concat([
      for name, attrs in v.fast_config.organization_iam : [
        for key in v.config.environments :
        {
          hg        = "${k}-${key}"
          key       = "${k}-${key}/${attrs.role}/${attrs.member}"
          role      = attrs.role
          member    = attrs.member
          condition = attrs.condition
        }
      ] if v._has.automation == true && startswith(attrs.member, "sa-r")
    ]) if v._has.envs
  ])
  # compute list of environment SAs
  _hg_service_accounts_env = flatten([
    for k, v in local.hierarchy_groups : [
      for key in v.config.environments : [
        {
          hg           = k
          key          = "${k}-${key}/sa-ro"
          name         = "${k}-${key}-0r"
          cicd_enabled = v.fast_config.cicd_config != null
        },
        {
          hg           = k
          key          = "${k}-${key}/sa-rw"
          name         = "${k}-${key}-0"
          cicd_enabled = v.fast_config.cicd_config != null
        }
      ]
    ] if v._has.envs && v._has.automation
  ])
  # compute map of group buckets for environments
  _hg_buckets_env = flatten([
    for k, v in local.hierarchy_groups : [
      for key in v.config.environments : [
        {
          hg  = k
          key = "${k}-${key}"
        }
      ]
    ] if v._has.envs && v._has.automation
  ])
  # transform folder list into a map
  hg_folders_env = {
    for v in local._hg_folders_env : v.key => {
      hg     = v.hg
      name   = v.name
      parent = v.parent
      config = local.hierarchy_groups[v.hg].folders_config
    }
  }
}
