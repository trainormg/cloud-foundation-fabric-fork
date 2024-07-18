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

# tfdoc:file:description Hierarchy group locals that process the variable data.

# Locals in this file generally implement two transformation stages:
#
# - _hg_xxx locals compute aggregated lists of resources across all hgroups
# - hg_xxx locals recompose the lists into maps usable in for_each

locals {
  # compute list of main and extra folders for all hierarchy groups
  _hg_folders = flatten([
    for k, v in local.hierarchy_groups : concat(
      [{
        hg     = k
        key    = k
        name   = v.name
        parent = v.parent
      }],
      [
        for key, name in v.config.extra_folders : {
          hg     = k
          key    = "${k}/${key}"
          name   = name
          parent = v.parent
        }
      ]
    )
  ])
  # compute list of billing IAM for all hierarchy groups
  _hg_iam_billing = flatten([
    for k, v in local.hierarchy_groups : concat(
      [
        for member in v.fast_config.billing_iam.cost_manager_principals : {
          hg     = k
          key    = "${k}/cost_manager/${member}"
          role   = "roles/billing.costsManager"
          member = lookup(var.groups, member, member)
        }
        # exclude per-environment SAs or SAs when automation is not enabled
        if((!v._has.envs && v._has.automation) || !startswith(member, "sa-r"))
      ],
      [
        for member in v.fast_config.billing_iam.user_principals : {
          hg     = k
          key    = "${k}/user/${member}"
          role   = "roles/billing.user"
          member = lookup(var.groups, member, member)
        }
        # exclude per-environment SAs or SAs when automation is not enabled
        if((!v._has.envs && v._has.automation) || !startswith(member, "sa-r"))
      ]
    )
  ])
  # compute list of org-level IAM for all hierarchy groups
  _hg_iam_org = flatten([
    for k, v in local.hierarchy_groups : concat([
      for name, attrs in v.fast_config.organization_iam : {
        hg        = k
        key       = "${k}/${attrs.role}/${attrs.member}"
        role      = attrs.role
        member    = lookup(var.groups, attrs.member, attrs.member)
        condition = attrs.condition
      }
      # exclude per-environment SAs or SAs when automation is not enabled
      if((!v._has.envs && v._has.automation) || !startswith(attrs.member, "sa-r"))
    ])
  ])
  # compute list of group service accounts as product of group and ro/rw
  _hg_service_accounts = flatten([
    for k, v in local.hierarchy_groups : [
      {
        hg           = k
        key          = "${k}/sa-ro"
        name         = "${k}-0r"
        cicd_enabled = v.fast_config.cicd_config != null
      },
      {
        hg           = k
        key          = "${k}/sa-rw"
        name         = "${k}-0"
        cicd_enabled = v.fast_config.cicd_config != null
      }
    ] if !v._has.envs && v._has.automation
  ])
  # compute map of group buckets for hierarchy groups with automation enabled
  hg_buckets = {
    for k, v in local.hierarchy_groups : k => v.fast_config
    if !v._has.envs && v._has.automation
  }
  # compute map of CI/CD configs for hierarchy groups with CI/CD enabled
  hg_cicd_configs = {
    for k, v in local.hierarchy_groups : k => v.fast_config.cicd_config
    if !v._has.envs && v._has.automation && v._has.cicd
  }
  # transform folder list into a map
  hg_folders = {
    for v in local._hg_folders : v.key => {
      hg     = v.hg
      name   = v.name
      parent = v.parent
      config = local.hierarchy_groups[v.hg].folders_config
    }
  }
  # transform billing IAM list into a map
  hg_iam_billing = {
    for v in concat(local._hg_iam_billing, local._hg_iam_billing_env) :
    v.key => {
      member = "${v.hg}/${v.member}"
      role   = v.role
    }
  }
  # transform org-level IAM list into a map
  hg_iam_org = {
    for v in concat(local._hg_iam_org, local._hg_iam_org_env) :
    v.key => {
      member    = "${v.hg}/${v.member}"
      role      = v.role
      condition = v.condition
    }
  }
  # compute list of org policy IAM bindings
  hg_orgpolicy = flatten([
    for k, v in local.hierarchy_groups : [
      for key, value in { rw = "Admin", ro = "Viewer" } : [
        {
          hg     = k
          key    = "${k}/roles/orgpolicy.policy${value}/sa-${key}"
          member = "${k}/sa-${key}"
          role   = "roles/orgpolicy.policy${value}"
          title  = "${k}_orgpol_${lower(value)}_sa_${key}"
          expression = (
            "resource.matchTag('${local.tag_parent}/fast-hg', '${k}')"
          )
        }
      ]
    ] if !v._has.envs && v.fast_config.orgpolicy_conditional_iam == true
  ])
  # transform service account list into a map
  hg_service_accounts = {
    for v in concat(local._hg_service_accounts, local._hg_service_accounts_env) :
    v.key => v
  }
  # merge hierarchy groups from the variable and factory files and normalize
  hierarchy_groups = {
    for k, v in merge(local._hierarchy_groups_f, var.hierarchy_groups) :
    k => merge(v, {
      # discard undeclared environments
      config = merge(v.config, {
        environments = [
          for key in v.config.environments :
          key if lookup(var.environments, key, null) != null
        ]
      })
      # convenience attrs to shorten comparisons used throughout most locals
      _has = {
        automation = v.fast_config.automation_enabled == true
        cicd       = v.fast_config.cicd_config != null
        envs       = length(v.config.environments) > 0
      }
    })
  }
}
