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

# tfdoc:file:description Branch-related locals to process the branches variable.

# This file only contains locals that process the branches variables, split
# in two broad sections:
#
# - "local" locals (_ prefix) are only used here and compute aggregated lists
#   of resources across all branches
# - "public" locals recompose the lists into maps that are then consumed
#   directly with for_each in resource blocks

locals {
  # recompose list of main and extra folders for all branches
  _branch_folders = flatten([
    for k, v in local.branches : concat([
      {
        branch = k
        key    = "${k}/main"
        name   = v.branch_name
      }
      ], [
      for key, name in v.extra_folders : {
        branch = k
        key    = "${k}/${key}"
        name   = name
      }
    ])
  ])
  # recompose list of billing IAM for all branches
  _branch_iam_billing = flatten([
    for k, v in local.branches : concat([
      for member in v.fast_config.billing_iam.cost_manager_principals : {
        branch = k
        key    = "${k}/cost_manager/${member}"
        role   = "roles/billing.costsManager"
        member = member
      }
      ], [
      for member in v.fast_config.billing_iam.user_principals : {
        branch = k
        key    = "${k}/user/${member}"
        role   = "roles/billing.user"
        member = member
      }
    ])
  ])
  # recompose list of org-level IAM for all branches
  _branch_iam_org = flatten([
    for k, v in local.branches : concat([
      for name, attrs in v.fast_config.organization_iam : {
        branch    = k
        key       = "${k}/${attrs.role}/${attrs.member}"
        role      = attrs.role
        member    = attrs.member
        condition = attrs.condition
      }
    ])
  ])
  # recompose list of branch service accounts as product of branch and ro/rw
  _branch_service_accounts = flatten([
    for k, v in local.branches : [
      {
        branch       = k
        key          = "${k}/sa-ro"
        name         = "${k}-0r"
        cicd_enabled = v.fast_config.cicd_config != null
      },
      {
        branch       = k
        key          = "${k}/sa-rw"
        name         = "${k}-0"
        cicd_enabled = v.fast_config.cicd_config != null
      }
    ] if v.fast_config.automation_enabled == true
  ])
  # map of branch buckets for branches with automation enabled
  branch_buckets = {
    for k, v in local.branches : k => v.fast_config
    if v.fast_config.automation_enabled == true
  }
  # map of CI/CD configs for branches with CI/CD enabled
  branch_cicd_configs = {
    for k, v in local.branches : k => v.fast_config.cicd_config
    if v.fast_config.cicd_config != null
  }
  # transform folder list into a map
  branch_folders = {
    for v in local._branch_folders : v.key => {
      config = local.branches[v.branch].folders_config
      branch = v.branch
      name   = v.name
    }
  }
  # transform billing IAM list into a map
  branch_iam_billing = {
    for v in local._branch_iam_billing : v.key => {
      member = "${v.branch}/${v.member}"
      role   = v.role
    }
  }
  # transform org-level IAM list into a map
  branch_iam_org = {
    for v in local._branch_iam_org : v.key => {
      member    = "${v.branch}/${v.member}"
      role      = v.role
      condition = v.condition
    }
  }
  # transform service account list into a map
  branch_service_accounts = {
    for v in local._branch_service_accounts : v.key => v
  }
  # merge branches from the variable and factory files
  branches = merge(
    local._branches_f,
    var.branches
  )
}
