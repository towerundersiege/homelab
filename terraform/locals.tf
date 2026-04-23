locals {
  default_description   = "Managed by Terraform for the towerundersiege homelab platform"
  cloud_image_import_id = "${var.cloud_image_datastore}:import/${var.cloud_image_file_name}"
}
