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

# TODO(ludo): move to stage 0 / globals
# TODO(ludo): change type to map(object) and add is_default boolean flag
variable "environments" {
  description = "Environment names."
  type        = map(string)
  nullable    = false
  default = {
    dev  = "Development"
    prod = "Production"
  }
}

variable "factories_config" {
  description = "Configuration for the resource factories or external data."
  type = object({
    hierarchy_groups = optional(string, "data/hierarchy-groups")
  })
  nullable = false
  default  = {}
}

variable "fast_features" {
  description = "Selective control for top-level FAST features."
  type = object({
    project_factory = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "outputs_location" {
  description = "Enable writing provider, tfvars and CI/CD workflow files to local filesystem. Leave null to disable."
  type        = string
  default     = null
}

variable "tags" {
  description = "Custom secure tags by key name. The `iam` attribute behaves like the similarly named one at module level."
  type = map(object({
    description = optional(string, "Managed by the Terraform organization module.")
    iam         = optional(map(list(string)), {})
    values = optional(map(object({
      description = optional(string, "Managed by the Terraform organization module.")
      iam         = optional(map(list(string)), {})
      id          = optional(string)
    })), {})
  }))
  nullable = false
  default  = {}
  validation {
    condition = alltrue([
      for k, v in var.tags : v != null
    ])
    error_message = "Use an empty map instead of null as value."
  }
}
