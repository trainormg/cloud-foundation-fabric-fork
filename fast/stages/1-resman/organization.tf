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

# tfdoc:file:description Organization-level IAM and tags.
output "foo" { value = local.env_tag_hgs }
locals {
  # map of stage 2 hierarchy groups who get permissions on env tag values
  env_tag_hgs = [
    for k, v in local.hierarchy_groups : k if(
      v.fast_config.automation_enabled == true &&
      length(v.config.environments) == 0 &&
      v.fast_config.stage_level == 2
    )
  ]
  # combine user-defined IAM on tag values
  tags = {
    for tag_k, tag_v in var.tags : tag_k => merge(tag_v, {
      values = {
        for value_k, value_v in tag_v.values : value_k => merge(value_v, {
          iam = {
            for role, principals in tag_v.iam : role => [
              for principal in principals : (
                try(module.hg-sa[principal].iam_email, principal)
              )
            ]
          }
        })
      }
    })
  }
}

module "organization" {
  source          = "../../../modules/organization"
  count           = var.root_node == null ? 1 : 0
  organization_id = "organizations/${var.organization.id}"
  iam_bindings_additive = merge(
    # branch roles from each hg fast_config.iam_organization
    {
      for k, v in local.hg_iam_org : k => {
        member    = try(module.hg-sa[v.member].iam_email, v.member)
        role      = lookup(var.custom_roles, v.role, v.role)
        condition = v.condition
      }
    },
    # branch billing roles from each hg fast_config.iam_billing
    local.billing_mode != "org" ? {} : {
      for k, v in local.hg_iam_billing : k => merge(v, {
        member = try(module.hg-sa[v.member].iam_email, v.member)
      })
    }
  )
  # be careful assigning tag viewer or user roles here as this is authoritative
  tags = merge(local.tags, {
    fast-hg = {
      description = "FAST hierarchy group."
      iam         = try(local.tags.fast-hg.iam, {})
      values = {
        for k, v in local.hierarchy_groups : k => {
          iam = try(local.tags["fast-hg"].values[k].iam, {})
        }
      }
    }
    fast-environment = {
      description = "FAST environment definition."
      iam         = try(local.tags.fast-environment.iam, {})
      values = {
        for k, v in var.environments : k => {
          iam = merge(
            try(local.tags.fast-environment.values[k].iam, {}),
            {
              "roles/resourcemanager.tagUser" = toset([
                for k in local.env_tag_hgs :
                module.hg-sa["${k}/sa-rw"].iam_email
              ])
              "roles/resourcemanager.tagViewer" = toset([
                for k in local.env_tag_hgs :
                module.hg-sa["${k}/sa-ro"].iam_email
              ])
            }
          )
        }
      }
    }
  })
}

# a second instance of the module is needed to prevent a cycle with tag values

module "organization-orgpolicy-iam" {
  source          = "../../../modules/organization"
  count           = var.root_node == null ? 1 : 0
  organization_id = "organizations/${var.organization.id}"
  iam_bindings_additive = {
    for v in concat(local.hg_orgpolicy, local.hg_orgpolicy_env) : v.key => {
      member = module.hg-sa[v.member].iam_email
      role   = v.role
      condition = {
        title       = v.title
        description = "Org policy admin for ${v.member} (conditional)."
        expression  = v.expression
      }
    }
  }
}
