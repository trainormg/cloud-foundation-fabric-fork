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
  # compute providers and tfvars file prefixes for each hierarchy group
  _hg_file_prefixes = {
    for k, v in local.hierarchy_groups :
    # name is [stage level]-[stage name]
    k => join("-", compact([v.fast_config.stage_level, k]))
    if v.fast_config.automation_enabled == true
  }
  # compute stage 3 CI/CD dependencies on stage 2 hierarchy group
  _cicd_stage2 = [
    for k, v in local._hg_file_prefixes : v if(
      local.hierarchy_groups[k].fast_config.automation_enabled == true &&
      local.hierarchy_groups[k].fast_config.stage_level == 2
    )
  ]
  # prepare CI/CD workflow attributes
  cicd_workflows = {
    for k, v in local.hg_cicd_configs : k => templatefile(
      "${path.module}/templates/workflow-${v.repository_type}.yaml", {
        audiences = try(
          local.identity_providers[v.identity_provider].audiences, null
        )
        identity_provider = try(
          local.identity_providers[v.identity_provider].name, null
        )
        outputs_bucket = var.automation.outputs_bucket
        service_accounts = {
          apply = module.hg-sa["${k}/sa-rw"].email
          plan  = module.hg-sa["${k}/sa-ro"].email
        }
        stage_name = k
        tf_providers_files = {
          apply = "${local._hg_file_prefixes[k]}-providers.tf"
          apply = "${local._hg_file_prefixes[k]}-r-providers.tf"
        }
        tf_var_files = (
          v.fast_config.stage_level == null
          # if the hierarchy group has no stage level it does not have dependencies
          ? []
          : concat(
            # stage 2s and 3s all depend on tfvars from 0 and 1
            [
              "0-globals.auto.tfvars.json",
              "0-bootstrap.auto.tfvars.json",
              "1-resman.auto.tfvars.json"
            ],
            # stage 3s also depend on stage 2s
            v.fast_config.stage_level == 2 ? [] : local._cicd_stage2
          )
        )
    })
  }
  # prepare hierarchy group provider attributes
  providers = merge(
    # read-write providers
    {
      for k, v in local._hg_file_prefixes : v => templatefile(
        "${path.module}/templates/providers.tf.tpl", {
          backend_extra = null
          bucket        = module.hg-gcs[k].name
          name          = k
          sa            = module.hg-sa["${k}/sa-rw"].email
        }
      )
    },
    # read-only providers
    {
      for k, v in local._hg_file_prefixes : "${v}-r" => templatefile(
        "${path.module}/templates/providers.tf.tpl", {
          backend_extra = null
          bucket        = module.hg-gcs[k].name
          name          = k
          sa            = module.hg-sa["${k}/sa-ro"].email
        }
      )
    }
  )
  # stage output vars
  tfvars = {
    folder_ids = {
      for k, v in module.hg-folders : k => v.id
    }
    service_accounts = {
      for k, v in module.hg-sa : k => v.email
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
