/**
 * Copyright 2021 Google LLC
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
  storage_sa  = data.google_storage_project_service_account.gcs_account.email_address
  dataflow_sa = google_project_service_identity.dataflow_sa.email
  compute_sa  = "service-${data.google_project.reid_project.number}@compute-system.iam.gserviceaccount.com"
  bigquery_sa = data.google_bigquery_default_service_account.bigquery_sa.email

  reidentification_key_name = "reidentification_kms_key_${random_id.suffix.hex}"
  bigquery_key_name         = "bigquery_kms_key_${random_id.suffix.hex}"

  reidentification_key_encrypters_decrypters = "serviceAccount:${local.storage_sa},serviceAccount:${local.dataflow_sa},serviceAccount:${local.compute_sa}"
  bigquery_key_encrypters_decrypters         = "serviceAccount:${local.bigquery_sa}"

  keys = [
    local.reidentification_key_name,
    local.bigquery_key_name
  ]

  encrypters = [
    local.reidentification_key_encrypters_decrypters,
    local.bigquery_key_encrypters_decrypters
  ]

  decrypters = [
    local.reidentification_key_encrypters_decrypters,
    local.bigquery_key_encrypters_decrypters
  ]
}

data "google_project" "reid_project" {
  project_id = var.privileged_data_project_id
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.privileged_data_project_id
}

data "google_bigquery_default_service_account" "bigquery_sa" {
  project = var.privileged_data_project_id
}

resource "google_project_service_identity" "dataflow_sa" {
  provider = google-beta

  project = var.privileged_data_project_id
  service = "dataflow.googleapis.com"
}

module "cmek" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 2.0.1"

  project_id          = var.taxonomy_project_id
  location            = var.cmek_location
  keyring             = var.cmek_keyring_name
  key_rotation_period = var.key_rotation_period_seconds
  prevent_destroy     = !var.delete_contents_on_destroy
  keys                = local.keys
  set_encrypters_for  = local.keys
  set_decrypters_for  = local.keys
  encrypters          = local.encrypters
  decrypters          = local.decrypters
}
