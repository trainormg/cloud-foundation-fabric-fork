/**
 * Copyright 2022 Google LLC
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

# tfdoc:file:description Billing resources for external billing use cases.

locals {
  billing_mode = (
    var.billing_account.no_iam
    ? null
    : var.billing_account.is_org_level ? "org" : "resource"
  )
}

# standalone billing account (org-level roles are in organization.tf)

resource "google_billing_account_iam_member" "default" {
  for_each = local.billing_mode != "resource" ? {} : {
    for k, v in local.branch_iam_billing : k => merge(v, {
      member = try(module.branch-sa[v.member].iam_email, v.member)
    })
  }
  billing_account_id = var.billing_account.id
  role               = each.value.role
  member             = each.value.member
}
