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

# tfdoc:file:description Hierarchy group resources for CI/CD support.

locals {
  _hg_cicd_sa = flatten([
    for k, v in local.hierarchy_groups : [
      {
        hg   = k
        cicd = v.fast_config.cicd_config
        key  = "${k}/sa-ro-cicd"
        name = "${k}-1r"
      },
      {
        hg   = k
        cicd = v.fast_config.cicd_config
        key  = "${k}/sa-rw-cicd"
        name = "${k}-1"
      }
    ] if v.fast_config.cicd_config != null
  ])
  hg_cicd = {
    for k, v in local.hierarchy_groups :
    k => v.fast_config.cicd_config if v.fast_config.cicd_config != null
  }
  hg_cicd_sa = {
    for v in local._hg_cicd_sa : v.key => v
  }
}

module "hg-cicd-sa" {
  source       = "../../../modules/iam-service-account"
  for_each     = local.hg_cicd_sa
  project_id   = var.automation.project_id
  name         = "resman-${each.value.name}"
  display_name = "Terraform resman CI/CD service account for ${each.value.hg}."
  prefix       = var.prefix
  iam = {
    "roles/iam.workloadIdentityUser" = [
      # read-only service accounts don't use hg-specific principal
      each.value.cicd.repository_hg == null || endswith(each.value.name, "r")
      ? format(
        local.identity_providers[each.value.cicd.identity_provider].principal_repo,
        var.automation.federated_identity_pool,
        each.value.cicd.repository_name
      )
      : format(
        local.identity_providers[each.value.cicd.identity_provider].principal_hg,
        var.automation.federated_identity_pool,
        each.value.cicd.repository_name,
        each.value.cicd.repository_hg
      )
    ]
  }
  iam_project_roles = {
    (var.automation.project_id) = ["roles/logging.logWriter"]
  }
  iam_storage_roles = {
    (var.automation.outputs_bucket) = ["roles/storage.objectViewer"]
  }
}

