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

# tfdoc:file:description Branch definition variables.

variable "hierarchy_groups" {
  description = "Hierarchy group definitions (merged with those from factory)."
  type = map(object({
    name          = string
    extra_folders = optional(map(string), {})
    parent        = optional(string)
    fast_config = optional(object({
      automation_enabled = optional(bool, true)
      stage_level        = optional(number)
      billing_iam = optional(object({
        cost_manager_principals = optional(list(string), [])
        user_principals         = optional(list(string), [])
      }), {})
      cicd_config = optional(object({
        repository_name   = string
        repository_type   = string
        repository_branch = optional(string)
        identity_provider = optional(string)
      }))
      organization_iam = optional(map(object({
        member = string
        role   = string
        condition = optional(object({
          expression  = string
          title       = string
          description = optional(string)
        }))
      })), {})
      orgpolicy_conditional_iam = optional(bool, false)
    }), {})
    folders_config = optional(object({
      contacts = optional(map(list(string)), {})
      firewall_policy = optional(object({
        name   = string
        policy = string
      }))
      logging_data_access = optional(map(map(list(string))), {})
      logging_exclusions  = optional(map(string), {})
      logging_settings = optional(object({
        disable_default_sink = optional(bool)
        storage_location     = optional(string)
      }))
      logging_sinks = optional(map(object({
        bq_partitioned_table = optional(bool, false)
        description          = optional(string)
        destination          = string
        disabled             = optional(bool, false)
        exclusions           = optional(map(string), {})
        filter               = optional(string)
        iam                  = optional(bool, true)
        include_children     = optional(bool, true)
        type                 = string
      })), {})
      iam = optional(map(list(string)), {})
      iam_bindings = optional(map(object({
        members = list(string)
        role    = string
        condition = optional(object({
          expression  = string
          title       = string
          description = optional(string)
        }))
      })), {})
      iam_bindings_additive = optional(map(object({
        member = string
        role   = string
        condition = optional(object({
          expression  = string
          title       = string
          description = optional(string)
        }))
      })), {})
      iam_by_principals = optional(map(list(string)), {})
      org_policies = optional(map(object({
        inherit_from_parent = optional(bool) # for list policies only.
        reset               = optional(bool)
        rules = optional(list(object({
          allow = optional(object({
            all    = optional(bool)
            values = optional(list(string))
          }))
          deny = optional(object({
            all    = optional(bool)
            values = optional(list(string))
          }))
          enforce = optional(bool) # for boolean policies only.
          condition = optional(object({
            description = optional(string)
            expression  = optional(string)
            location    = optional(string)
            title       = optional(string)
          }), {})
        })), [])
      })), {})
      tag_bindings = optional(map(string), {})
    }), {})
  }))
  nullable = false
  default  = {}
  validation {
    condition = alltrue([
      for k, v in var.hierarchy_groups : (
        v.fast_config.cicd_config == null ||
        v.fast_config.automation_enabled == true
      )
    ])
    error_message = "Hierarchy groups with CI/CD configured also need automation enabled."
  }
  validation {
    condition = alltrue([
      for k, v in var.hierarchy_groups : (
        try(v.fast_config.automation.enabled, null) == true ||
        (
          v.fast_config.billing_iam.cost_manager_principals == []
          &&
          v.fast_config.billing_iam.user_principals == []
          &&
          length(v.fast_config.organization_iam) == 0
          &&
          v.fast_config.orgpolicy_conditional_iam != true
        )
      )
    ])
    error_message = "FAST config is unused when FAST automation is disabled."
  }
}
