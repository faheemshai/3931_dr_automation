# ---------------------------------------------------------------
# packer/variables.pkr.hcl
#
# All Packer input variable declarations for LAB-3931.
# Values are supplied via student.pkrvars.hcl (gitignored).
# ---------------------------------------------------------------

# ── Authentication ───────────────────────────────────────────────
variable "ibm_api_key" {
  description = <<-EOT
    IBM Cloud API key used by the Packer IBM Cloud plugin to create
    the temporary build VSI. This key is NEVER baked into the image.
    In the lab, retrieve this from Vault before running packer build:
      export IBM_API_KEY=$(vault kv get -field=ibm_api_key kv/IBM_cloud)
      packer build -var="ibm_api_key=$IBM_API_KEY" ...
    or supply it in student.pkrvars.hcl (which is gitignored).
  EOT
  type        = string
  sensitive   = true
}

# ── Student identity ─────────────────────────────────────────────
variable "student_id" {
  description = "Student identifier — stamped into /etc/os-release on the golden image"
  type        = string
  default     = "student-01"
}

# ── Image naming ─────────────────────────────────────────────────
variable "image_name_prefix" {
  description = <<-EOT
    Prefix for the output image name. A timestamp is appended automatically.
    Example: "rhel92-golden" → "rhel92-golden-20260601-1430-us-south"
  EOT
  type    = string
  default = "rhel92-golden"
}

# ── Base image ───────────────────────────────────────────────────
variable "base_image_name" {
  description = <<-EOT
    IBM Cloud stock RHEL 9.2 image to use as the Packer build source.
    Confirm the exact name in your account:
      ibmcloud is images --visibility public | grep -i "rhel-9-2"
    Common value: ibm-redhat-9-2-minimal-amd64-9
  EOT
  type    = string
  default = "ibm-redhat-9-2-minimal-amd64-9"
}

# ── IBM Cloud resource group ──────────────────────────────────────
variable "ibm_resource_group_id" {
  description = <<-EOT
    Resource group ID where the output images will be stored.
    Retrieve with: ibmcloud resource group <name> --id
  EOT
  type = string
}

# ── us-south (primary) build settings ────────────────────────────
variable "us_south_zone" {
  description = "IBM Cloud zone for the temporary build VSI in us-south"
  type        = string
  default     = "us-south-1"
}

variable "build_vpc_name_us_south" {
  description = <<-EOT
    Name of the VPC in us-south where the temporary Packer build VSI
    will be created. The VPC must already exist and have a subnet in
    the target zone with a public gateway for dnf updates.
    Create one-time with: ibmcloud is vpc-create packer-build-vpc-us-south
  EOT
  type = string
}

# ── eu-de (DR) build settings ────────────────────────────────────
variable "eu_de_zone" {
  description = "IBM Cloud zone for the temporary build VSI in eu-de"
  type        = string
  default     = "eu-de-2"
}

variable "build_vpc_name_eu_de" {
  description = <<-EOT
    Name of the VPC in eu-de where the temporary Packer build VSI
    will be created. Same requirements as build_vpc_name_us_south.
    Create one-time with: ibmcloud is vpc-create packer-build-vpc-eu-de
  EOT
  type = string
}
