# ---------------------------------------------------------------
# packer/variables.pkr.hcl
#
# All Packer input variable declarations for LAB-3931.
# Values are supplied via student.pkrvars.hcl (gitignored).
# ---------------------------------------------------------------

# ── Authentication ───────────────────────────────────────────────
variable "ibm_api_key" {
  description = "IBM Cloud API key for the Packer build. Never hard-coded — supply via student.pkrvars.hcl or env var IBM_API_KEY."
  type        = string
  sensitive   = true
  default     = "${env("IBM_API_KEY")}"
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

# ── Pre-existing SSH key (bypasses Packer key generation) ────────
variable "ssh_private_key_file" {
  description = <<-EOT
    Path to the private key whose public key is already registered as an
    IBM Cloud SSH key. Packer uses this to connect instead of generating
    a throwaway key. The matching public key must be registered in IBM Cloud
    and its ID supplied via existing_ssh_key_id_us_south.
    Example: "/Users/you/.ssh/id_rsa"
  EOT
  type = string
}

variable "existing_ssh_key_id_us_south" {
  description = <<-EOT
    IBM Cloud SSH key ID (format: r006-xxxxxxxx-...) already registered in
    us-south. Packer attaches this key to the build VSI so cloud-init injects
    the matching public key into /root/.ssh/authorized_keys at first boot.
    Get it: IBM Cloud Console → VPC Infrastructure → SSH keys → copy the ID.
  EOT
  type = string
}

variable "existing_ssh_key_id_eu_de" {
  description = "IBM Cloud SSH key ID registered in eu-de. Leave empty to reuse the us-south key ID."
  type    = string
  default = ""
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
