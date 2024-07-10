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
  # compute providers and tfvars file prefixes for each branch
  _branch_file_prefixes = {
    for k, v in var.branches :
    k => join("-", compact([v.fast_config.stage_level, k]))
    if v.fast_config.automation == true
  }
  # compute stage 3 CI/CD dependencies on stage 2 branches
  _cicd_stage2 = [
    for k, v in local._branch_file_prefixes : v if(
      var.branches[k].fast_config.automation == true &&
      var.branches[k].fast_config.stage_level == 2
    )
  ]
  # prepare CI/CD workflow attributes
  cicd_workflows = {
    for k, v in local.branch_cicd_configs : k => {
      service_accounts = {
        apply = module.branch-sa["${k}/sa-rw"].email
        plan  = module.branch-sa["${k}/sa-ro"].email
      }
      tf_providers_files = {
        apply = "${local._branch_file_prefixes[k]}-providers.tf"
        apply = "${local._branch_file_prefixes[k]}-r-providers.tf"
      }
      tf_var_files = v.fast_config.stage_level == null ? [] : concat(
        [
          "0-globals.auto.tfvars.json",
          "0-bootstrap.auto.tfvars.json",
          "1-resman.auto.tfvars.json"
        ],
        v.fast_config.stage_level == 2 ? [] : local._cicd_stage2
      )
    }
  }
  # prepare branch provider attributes
  providers = {
    for k, v in local._branch_file_prefixes : v => {
      backend_extra = null
      bucket        = module.branch-gcs[k].name
      name          = k
      sa            = module.branch-sa[k].email
    }
  }
  # stage output vars
  tfvars = {
    folder_ids = {
      for k, v in module.branch-folders : k => v.id
    }
    service_accounts = {
      for k, v in module.branch-sa : k => v.email
    }
    tag_keys = (
      var.root_node == null
      ? module.organization[0].tag_keys
      : module.automation-project[0].tag_keys
    )
    tag_names = var.tag_names
    tag_values = (
      var.root_node == null
      ? module.organization[0].tag_values
      : module.automation-project[0].tag_values
    )
  }
}

output "stage_vars" {
  description = "Output variables of this stage."
  value       = local.tfvars
}
