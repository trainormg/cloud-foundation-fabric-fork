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

# tfdoc:file:description Main hierarchy group resources.

module "hg-folders" {
  source              = "../../../modules/folder"
  for_each            = local.hg_folders
  parent              = local.root_node
  name                = each.value.name
  contacts            = each.value.config.contacts
  firewall_policy     = each.value.config.firewall_policy
  logging_data_access = each.value.config.logging_data_access
  logging_exclusions  = each.value.config.logging_exclusions
  logging_settings    = each.value.config.logging_settings
  logging_sinks       = each.value.config.logging_sinks
  iam = {
    for k, v in each.value.config.iam : k => [
      for vv in v : try(
        module.hg-sa["${each.value.hg}/${vv}"].iam_email,
        lookup(var.groups, vv, vv)
      )
    ]
  }
  iam_bindings = {
    for k, v in each.value.config.iam_bindings : k => merge(v, {
      member = try(
        module.hg-sa["${each.value.hg}/${v.member}"].iam_email,
        lookup(var.groups, v.member, v.member)
      )
    })
  }
  iam_bindings_additive = {
    for k, v in each.value.config.iam_bindings : k => merge(v, {
      member = try(
        module.hg-sa["${each.value.hg}/${v.member}"].iam_email,
        lookup(var.groups, v.member, v.member)
      )
    })
  }
  # dynamic keys are not supported here so don't look for substitutions
  iam_by_principals = {
    for k, v in each.value.config.iam_by_principals :
    lookup(var.groups, k, k) => v
  }
  org_policies = each.value.config.org_policies
  tag_bindings = {
    for k, v in each.value.config.tag_bindings :
    k => lookup(local.tag_values, v, v)
  }
}

module "hg-sa" {
  source                 = "../../../modules/iam-service-account"
  for_each               = local.hg_service_accounts
  project_id             = var.automation.project_id
  name                   = "resman-${each.value.name}"
  display_name           = "Terraform resman service account for ${each.value.hg}."
  prefix                 = var.prefix
  service_account_create = var.root_node == null
  iam = !each.value.cicd_enabled ? {} : {
    "roles/iam.serviceAccountTokenCreator" = [
      module.hg-cicd-sa["${each.key}-cicd"].iam_email
    ]
  }
  iam_project_roles = {
    (var.automation.project_id) = ["roles/serviceusage.serviceUsageConsumer"]
  }
  iam_storage_roles = !endswith(each.key, "sa-rw") ? {} : {
    (var.automation.outputs_bucket) = ["roles/storage.objectAdmin"]
  }
}

module "hg-gcs" {
  source        = "../../../modules/gcs"
  for_each      = local.hg_buckets
  project_id    = var.automation.project_id
  name          = "prod-resman-${each.key}-0"
  prefix        = var.prefix
  location      = var.locations.gcs
  storage_class = local.gcs_storage_class
  versioning    = true
  iam = {
    "roles/storage.objectAdmin" = [
      module.hg-sa["${each.key}/sa-rw"].iam_email
    ]
    "roles/storage.objectViewer" = [
      module.hg-sa["${each.key}/sa-ro"].iam_email
    ]
  }
}
