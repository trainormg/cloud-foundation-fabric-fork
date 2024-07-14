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
    (var.tag_names.context) = {
      description = "Resource management context."
      iam         = try(local.tags.context.iam, {})
      values = {
        data = {
          iam = try(local.tags.context.values.data.iam, {})
        }
        gke = {
          iam = try(local.tags.context.values.gke.iam, {})
        }
        gcve = {
          iam = try(local.tags.context.values.gcve.iam, {})
        }
        networking = {
          iam = try(local.tags.context.values.networking.iam, {})
        }
        project-factory = {
          iam = try(local.tags.context.values.project-factory.iam, {})
        }
        sandbox = {
          iam = try(local.tags.context.values.sandbox.iam, {})
        }
        security = {
          iam = try(local.tags.context.values.security.iam, {})
        }
      }
    }
    (var.tag_names.environment) = {
      description = "Environment definition."
      iam         = try(local.tags.environment.iam, {})
      values = {
        development = {
          iam = try(local.tags.environment.values.development.iam, {})
        }
        production = {
          iam = try(local.tags.environment.values.production.iam, {})
        }
      }
    }
  })
}
