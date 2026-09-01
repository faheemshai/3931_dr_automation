# ---------------------------------------------------------------
# packer/variables.pkr.hcl
#
# All Packer input variable declarations for LAB-3931.
# Values are supplied via student.pkrvars.hcl (gitignored).
#
# ── Two types of credentials in this lab ────────────────────────
#
# TYPE 1 — Packer input variables (CAN be set in student.pkrvars.hcl):
#   ibm_api_key    → declared here, read by source blocks in the template
#
# TYPE 2 — HCP registry env vars (CANNOT be in student.pkrvars.hcl):
#   HCP_CLIENT_ID, HCP_CLIENT_SECRET, HCP_ORGANIZATION_ID, HCP_PROJECT_ID
#   These are read by the Packer binary itself for hcp_packer_registry —
#   they are NOT Packer input variables and have no HCL declaration.
#   Use:  source packer/scripts/set-build-env.sh
#   That script reads all four from Vault and exports them for you.
# ---------------------------------------------------------------

# ── Authentication ───────────────────────────────────────────────
variable "ibm_api_key" {
  description = <<-EOT
    IBM Cloud API key for the Packer build.
    Set this in student.pkrvars.hcl (gitignored) — it is safe because
    the file is never committed. Alternatively leave it empty ("") and
    set IBM_API_KEY in your shell via set-build-env.sh.
    env("IBM_API_KEY") is the fallback when the var file value is empty.
  EOT
  type      = string
  sensitive = true
  default   = "${env("IBM_API_KEY")}"
}

# ── Student identity ─────────────────────────────────────────────
variable "student_id" {
  description = "Student identifier stamped into /etc/os-release on the golden image."
  type        = string
  default     = "student-01"
}

# ── Image naming ─────────────────────────────────────────────────
variable "image_name_prefix" {
  description = "Prefix for output image name. Compact timestamp appended automatically."
  type        = string
  default     = "rhel92-golden"
}

# ── Base image ───────────────────────────────────────────────────
variable "base_image_name" {
  description = "IBM Cloud RHEL 9 image name. Use non-minimal for full cloud-init VPC key injection support."
  type        = string
  default     = "ibm-redhat-9-4-amd64-5"
}

# ── IBM Cloud resource group ──────────────────────────────────────
variable "ibm_resource_group_id" {
  description = "Resource group ID for output images. Get: ibmcloud resource group <name> --id"
  type        = string
}

# ── us-south subnet ──────────────────────────────────────────────
variable "subnet_id_us_south" {
  description = <<-EOT
    Subnet ID in us-south for the temporary Packer build VSI.
    The subnet must have a public gateway attached for dnf internet access.
    Get IDs: ibmcloud is subnets | grep us-south
  EOT
  type = string
}

# ── us-south VPC default security group ──────────────────────────
variable "vpc_default_sg_id_us_south" {
  description = <<-EOT
    Default security group ID of the VPC in us-south.
    Packer adds its SSH allow rule to this group so it takes effect.
    Get it: ibmcloud is vpc <vpc-id> --output json | jq -r '.default_security_group.id'
    The VPC ID is printed in the packer build output as "VPC ID: r006-..."
  EOT
  type    = string
  default = ""
}

# ── eu-de subnet ─────────────────────────────────────────────────
variable "subnet_id_eu_de" {
  description = <<-EOT
    Subnet ID in eu-de for the temporary Packer build VSI.
    Same public gateway requirement as subnet_id_us_south.
    Get IDs: ibmcloud is subnets | grep eu-de
    Leave empty ("") when build_eu_de = false.
  EOT
  type    = string
  default = ""
}

# ── Region control ───────────────────────────────────────────────
variable "build_eu_de" {
  description = "Set to true to build in eu-de as well as us-south. Requires subnet_id_eu_de to be set."
  type        = bool
  default     = false
}
