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

# tfdoc:file:description Hierarchy group environment folders.

# we need a separate module invocation to prevent circular references

module "hg-folders-env" {
  source              = "../../../modules/folder"
  for_each            = local.hg_folders_env
  parent              = module.hg-folders[each.value.parent].id
  name                = each.value.name
  contacts            = each.value.config.contacts
  firewall_policy     = each.value.config.firewall_policy
  logging_data_access = each.value.config.logging_data_access
  logging_exclusions  = each.value.config.logging_exclusions
  logging_settings    = each.value.config.logging_settings
  logging_sinks       = each.value.config.logging_sinks
  iam = {
    for k, v in each.value.config.iam :
    lookup(var.custom_roles, k, k) => [
      for vv in v : try(
        module.hg-sa["${each.value.hg}/${vv}"].iam_email,
        module.hg-sa[vv].iam_email,
        lookup(var.groups, vv, vv)
      )
    ]
  }
  iam_bindings = {
    for k, v in each.value.config.iam_bindings : k => {
      member = try(
        module.hg-sa["${each.value.hg}/${v.member}"].iam_email,
        module.hg-sa[v.member].iam_email,
        lookup(var.groups, v.member, v.member)
      )
      role = lookup(var.custom_roles, v.role, v.role)
      condition = try(v.condition, null) == null ? null : merge(v.condition, {
        expression = (
          try(v.condition.match_tags, null) == null
          ? try(v.condition.expression, null)
          : join(" || ", [
            # TODO: use automation project for multitenants
            for t in v.condition.match_tags :
            "resource.matchTag('${var.organization.id}/${t.key}', '${t.value}')"
          ])
        )
      })
    }
  }
  iam_bindings_additive = {
    for k, v in each.value.config.iam_bindings : k => {
      member = try(
        module.hg-sa["${each.value.hg}/${v.member}"].iam_email,
        module.hg-sa[v.member].iam_email,
        lookup(var.groups, v.member, v.member)
      )
      role = lookup(var.custom_roles, v.role, v.role)
      condition = try(v.condition, null) == null ? null : merge(v.condition, {
        expression = (
          try(v.condition.match_tags, null) == null
          ? try(v.condition.expression, null)
          : join(" || ", [
            # TODO: use automation project for multitenants
            for t in v.condition.match_tags :
            "resource.matchTag('${var.organization.id}/${t.key}', '${t.value}')"
          ])
        )
      })
    }
  }
  # dynamic keys are not supported here so don't look for substitutions
  iam_by_principals = {
    for k, v in each.value.config.iam_by_principals :
    lookup(var.groups, k, k) => [
      for role in v : lookup(var.custom_roles, role, role)
    ]
  }
  org_policies = each.value.config.org_policies
  tag_bindings = merge(
    {
      fast-environment = local.tag_values["fast-environment/${each.value.env}"]
    },
    # dereference user-specified tag bindings
    {
      for k, v in each.value.config.tag_bindings :
      k => lookup(local.tag_values, v, v)
    }
  )
}
