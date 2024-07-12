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

# tfdoc:file:description Hierarchy group locals that process the variable data.

# This file only contains locals that process the hg variables, split
# in two broad sections:
#
# - "local" locals (_ prefix) are only used here and compute aggregated lists
#   of resources across all hgs
# - "public" locals recompose the lists into maps that are then consumed
#   directly with for_each in resource blocks

locals {
  # recompose list of main and extra folders for all hierarchy groups
  _hg_folders = flatten([
    for k, v in local.hierarchy_groups : concat([
      {
        hg   = k
        key  = "${k}/main"
        name = v.name
      }
      ], [
      for key, name in v.extra_folders : {
        hg   = k
        key  = "${k}/${key}"
        name = name
      }
    ])
  ])
  # recompose list of billing IAM for all hierarchy groups
  _hg_iam_billing = flatten([
    for k, v in local.hierarchy_groups : concat([
      for member in v.fast_config.billing_iam.cost_manager_principals : {
        hg     = k
        key    = "${k}/cost_manager/${member}"
        role   = "roles/billing.costsManager"
        member = lookup(var.groups, member, member)
      }
      ], [
      for member in v.fast_config.billing_iam.user_principals : {
        hg     = k
        key    = "${k}/user/${member}"
        role   = "roles/billing.user"
        member = lookup(var.groups, member, member)
      }
    ])
  ])
  # recompose list of org-level IAM for all hierarchy groups
  _hg_iam_org = flatten([
    for k, v in local.hierarchy_groups : concat([
      for name, attrs in v.fast_config.organization_iam : {
        hg        = k
        key       = "${k}/${attrs.role}/${attrs.member}"
        role      = attrs.role
        member    = lookup(var.groups, attrs.member, attrs.member)
        condition = attrs.condition
      }
    ])
  ])
  # recompose list of group service accounts as product of group and ro/rw
  _hg_service_accounts = flatten([
    for k, v in local.hierarchy_groups : [
      {
        hg           = k
        key          = "${k}/sa-ro"
        name         = "${k}-0r"
        cicd_enabled = v.fast_config.cicd_config != null
      },
      {
        hg           = k
        key          = "${k}/sa-rw"
        name         = "${k}-0"
        cicd_enabled = v.fast_config.cicd_config != null
      }
    ] if v.fast_config.automation_enabled == true
  ])
  # map of group buckets for hierarchy groups with automation enabled
  hg_buckets = {
    for k, v in local.hierarchy_groups : k => v.fast_config
    if v.fast_config.automation_enabled == true
  }
  # map of CI/CD configs for hierarchy groups with CI/CD enabled
  hg_cicd_configs = {
    for k, v in local.hierarchy_groups : k => v.fast_config.cicd_config
    if v.fast_config.cicd_config != null
  }
  # transform folder list into a map
  hg_folders = {
    for v in local._hg_folders : v.key => {
      config = local.hierarchy_groups[v.hg].folders_config
      hg     = v.hg
      name   = v.name
    }
  }
  # transform billing IAM list into a map
  hg_iam_billing = {
    for v in local._hg_iam_billing : v.key => {
      member = "${v.hg}/${v.member}"
      role   = v.role
    }
  }
  # transform org-level IAM list into a map
  hg_iam_org = {
    for v in local._hg_iam_org : v.key => {
      member    = "${v.hg}/${v.member}"
      role      = v.role
      condition = v.condition
    }
  }
  # transform service account list into a map
  hg_service_accounts = {
    for v in local._hg_service_accounts : v.key => v
  }
  # merge hierarchy groups from the variable and factory files
  hierarchy_groups = merge(
    local._hierarchy_groups_f,
    var.hierarchy_groups
  )
}
