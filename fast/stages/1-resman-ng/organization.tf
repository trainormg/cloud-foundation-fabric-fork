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

locals {
  env_tag_hgs = [
    for k, v in local.hierarchy_groups :
    k if try(v.fast_config.stage_level, null) == 2
  ]
  tags = {
    for tag_k, tag_v in var.tags : tag_k => merge(tag_v, {
      values = {
        for value_k, value_v in tag_v.values : value_k => merge(value_v, {
          iam = {
            for role, principals in tag_v.iam : role => [
              for principal in principals : (
                # try replacing branch/sa-ro branch/sa-rw format principals
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
        development = {
          iam = merge(
            try(local.tags.fast-environment.values.development.iam, {}),
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
        production = {
          iam = merge(
            try(local.tags.fast-environment.values.production.iam, {}),
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
  iam_bindings_additive = merge(
    {
      for k, v in local.hierarchy_groups :
      "${k}/roles/orgpolicy.policyAdmin/sa-rw" => {
        member = module.hg-sa["${k}/sa-rw"].iam_email
        role   = "roles/orgpolicy.policyAdmin"
        condition = {
          title       = "${k}_orgpol_admin_sa_rw"
          description = "Org policy admin for ${k} rw (conditional)."
          expression  = "resource.matchTag('${var.organization.id}/fast-hg', '${k}')"
        }
      } if v.fast_config.orgpolicy_conditional_iam == true
    },
    {
      for k, v in local.hierarchy_groups :
      "${k}/roles/orgpolicy.policyViewer/sa-ro" => {
        member = module.hg-sa["${k}/sa-ro"].iam_email
        role   = "roles/orgpolicy.policyViewer"
        condition = {
          title       = "${k}_orgpol_admin_sa_ro"
          description = "Org policy admin for ${k} ro (conditional)."
          expression  = "resource.matchTag('${var.organization.id}/fast-hg', '${k}')"
        }
      } if v.fast_config.orgpolicy_conditional_iam == true
    }
  )
}
