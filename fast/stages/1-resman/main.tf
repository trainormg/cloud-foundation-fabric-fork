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
  _tag_root = (
    var.root_node == null
    ? module.organization[0]
    : module.automation-project[0]
  )
  env_default = [for k, v in var.environments : k if v.is_default][0]
  gcs_storage_class = (
    length(split("-", var.locations.gcs)) < 2
    ? "MULTI_REGIONAL"
    : "REGIONAL"
  )
  # guard against this attribute being null
  identity_providers = coalesce(
    try(var.automation.federated_identity_providers, null), {}
  )
  root_node = (
    var.root_node == null
    ? "organizations/${var.organization.id}"
    : var.root_node
  )
  tag_parent = (
    var.root_node == null
    ? var.organization.id
    : var.automation.project_number
  )
  tag_values = {
    for k, v in local._tag_root.tag_values : k => v.id
  }
}
