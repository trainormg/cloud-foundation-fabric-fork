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

locals {
  _branch_folders = flatten([
    for k, v in var.branches : concat([
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
  _branch_iam_org = flatten([
    for k, v in var.branches : concat([
      for name, attrs in v.fast_config.organization_iam : {
        branch    = k
        key       = "${k}/${attrs.role}/${attrs.member}"
        role      = attrs.role
        member    = attrs.member
        condition = attrs.condition
      }
    ])
  ])
  _branch_service_accounts = flatten([
    for k, v in var.branches : [
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
  branch_cicd_configs = {
    for k, v in var.branches : k => v.fast_config.cicd_config
  }
  branch_folders = {
    for v in local._branch_folders : v.key => {
      config = var.branches[v.branch].folders_config
      branch = v.branch
      name   = v.name
    }
  }
  branch_iam_billing = flatten([
    for k, v in var.branches : concat([
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
  branch_iam_org = {
    for v in local._branch_iam_org : v.key => {
      member    = "${v.branch}/${v.member}"
      role      = v.role
      condition = v.condition
    }
  }
  branch_service_accounts = {
    for v in local._branch_service_accounts : v.key => v
  }
}

output "tmp" {
  value = {
    folders     = local.branch_folders
    iam_billing = local.branch_iam_billing
    iam_org     = local.branch_iam_org
    sas         = local.branch_service_accounts
  }
}
