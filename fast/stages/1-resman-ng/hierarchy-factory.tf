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

# tfdoc:file:description Hierarchy group factory locals.

locals {
  # read and decode factory files
  _hierarchy_groups_f_path = try(
    pathexpand(var.factories_config.hierarchy_groups), null
  )
  _hierarchy_groups_f_files = try(
    fileset(local._hierarchy_groups_f_path, "**/*.yaml"),
    []
  )
  _hierarchy_groups_f_raw = {
    for f in local._hierarchy_groups_f_files :
    split(".", f)[0] => yamldecode(file(
      "${coalesce(local._hierarchy_groups_f_path, "-")}/${f}"
    ))
  }
  # recompose with optional and default attributes
  _hierarchy_groups_f = {
    for k, v in local._hierarchy_groups_f_raw :
    # allow overriding filename with explicit key
    coalesce(try(v.key, null), k) => merge(v, {
      # fail if this is not defined
      name          = v.name
      extra_folders = try(v.extra_folders, {})
      parent        = try(v.parent, null)
      fast_config = {
        automation_enabled = try(v.fast_config.automation_enabled, true)
        stage_level        = try(v.fast_config.stage_level, 2)
        billing_iam = {
          cost_manager_principals = try(
            v.fast_config.billing_iam.cost_manager_principals, []
          )
          user_principals = try(
            v.fast_config.billing_iam.user_principals, []
          )
        }
        cicd_config = try(v.fast_config.cicd_config, null)
        organization_iam = {
          for k, v in try(v.fast_config.organization_iam, {}) : k => merge({
            condition = null
          }, v)
        }
        orgpolicy_conditional_iam = try(
          v.fast_config.orgpolicy_conditional_iam, false
        )
      }
      folders_config = {
        contacts              = try(v.folders_config.contacts, {})
        firewall_policy       = try(v.folders_config.firewall_policy, null)
        logging_data_access   = try(v.folders_config.logging_data_access, {})
        logging_exclusions    = try(v.folders_config.logging_exclusions, {})
        logging_settings      = try(v.folders_config.logging_settings, null)
        logging_sinks         = try(v.folders_config.logging_sinks, {})
        iam                   = try(v.folders_config.iam, {})
        iam_bindings          = try(v.folders_config.iam_bindings, {})
        iam_bindings_additive = try(v.folders_config.iam_bindings_additive, {})
        iam_by_principals     = try(v.folders_config.iam_by_principals, {})
        org_policies          = try(v.folders_config.org_policies, {})
        tag_bindings          = try(v.folders_config.tag_bindings, {})
      }
    })
  }
}
