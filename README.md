# LAB-3931 — DR Automation · Terraform + Vault + Packer on IBM Cloud

This repository contains all Terraform infrastructure code, Packer golden image
configuration, and lab scripts for IBM TechXchange LAB-3931.

## Repository layout

```
3931_dr_automation/
├── main.tf                   Root orchestrator — primary + DR modules, count gating
├── providers.tf              Vault JWT + ibm.primary + ibm.dr + hcp providers
├── variables.tf              All input variables including DR_infra bool
├── outputs.tf                Floating IPs, VSI IDs, vault_secret_version
├── versions.tf               HCP Terraform cloud backend config
├── terraform.tfvars          Region/zone/image/VPC values (no secrets)
│
├── modules/
│   ├── vault_integration/    Reads kv/IBM_cloud → ssh_public_key + secret_version
│   ├── vpc/                  VPC/subnet lookup by ID
│   ├── security_groups/      VSI security group — SSH+HTTP+HTTPS in, all out
│   └── vsi/                  ibm_is_instance + ibm_is_floating_ip, dr-role tags
│
├── packer/
│   ├── rhel92-ibmcloud.pkr.hcl   Packer template — us-south + eu-de sources
│   ├── variables.pkr.hcl         Variable declarations
│   ├── packer-manifest.json      Build record with both region image IDs
│   ├── student.pkrvars.hcl.example  Example vars file (gitignored live copy)
│   ├── sbom/                     CycloneDX SBOM output (generated at build time)
│   └── scripts/
│       ├── harden-rhel92.sh      8-step CIS RHEL 9 hardening
│       ├── hcp-register-build.sh HCP Packer REST registration
│       └── demo-hcp-packer.sh    Live demo script (8 sections)
│
└── scripts/
    └── trigger-dr-failover.sh    Disaster simulation — stops primary VSIs by tag
```

## Student quick start

Students do **not** interact with this repo directly.
Follow the steps in [`LAB_GUIDE.md`](../LAB_GUIDE.md) at the root of the workspace.

## Instructor notes

See [`INSTRUCTOR-GUIDE.md`](../INSTRUCTOR-GUIDE.md) for pre-lab setup, student
provisioning, monitoring, and cleanup procedures.
