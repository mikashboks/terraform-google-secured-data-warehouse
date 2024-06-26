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
  template_id        = "${var.template_id_prefix}_${var.random_template_id_suffix}"
  template_full_path = "projects/${var.project_id}/locations/${var.dlp_location}/deidentifyTemplates/${local.template_id}"

  template_file_sha256 = filesha256(var.template_file)

  de_identification_template = templatefile(
    var.template_file,
    {
      crypto_key   = var.crypto_key,
      wrapped_key  = var.wrapped_key,
      template_id  = local.template_id,
      display_name = var.template_display_name,
      description  = var.template_description
    }
  )
}

/* resource "random_id" "random_template_id_suffix" {
  byte_length = 8

  keepers = {
    crypto_key      = var.crypto_key,
    wrapped_key     = var.wrapped_key,
    template_sha256 = local.template_file_sha256
  }
} */

resource "google_kms_crypto_key_iam_member" "dlp_decrypters" {
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  crypto_key_id = var.crypto_key
  member        = "serviceAccount:${var.dataflow_service_account}"
}

resource "google_kms_crypto_key_iam_member" "dlp_encrypters" {
  role          = "roles/cloudkms.cryptoKeyEncrypter"
  crypto_key_id = var.crypto_key
  member        = "serviceAccount:${var.dataflow_service_account}"
}

resource "null_resource" "de_identify_template" {

  triggers = {
 #   template                  = local.de_identification_template,
    deidentified_fields_trigger    = var.deidentified_fields_trigger
    project_id                = var.project_id,
    template_id               = local.template_id
    dlp_location              = var.dlp_location
    terraform_service_account = var.terraform_service_account
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOF
    curl -s https://dlp.googleapis.com/v2/projects/${var.project_id}/locations/${var.dlp_location}/deidentifyTemplates \
    --header "X-Goog-User-Project: ${var.project_id}" \
    --header "Authorization: Bearer $(gcloud auth print-access-token --impersonate-service-account=${var.terraform_service_account})" \
    --header 'Accept: application/json' \
    --header "Content-Type: application/json" \
    --data '${local.de_identification_template}'
EOF

  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
    curl -s --request DELETE \
    https://dlp.googleapis.com/v2/projects/${self.triggers.project_id}/locations/${self.triggers.dlp_location}/deidentifyTemplates/${self.triggers.template_id} \
    --header "X-Goog-User-Project: ${self.triggers.project_id}" \
    --header "Authorization: Bearer $(gcloud auth print-access-token --impersonate-service-account=${self.triggers.terraform_service_account})" \
    --header 'Accept: application/json' \
    --header "Content-Type: application/json"
EOF

  }
}
