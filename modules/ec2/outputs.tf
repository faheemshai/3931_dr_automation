# ---------------------------------------------------------------
# modules/ec2/outputs.tf
# ---------------------------------------------------------------

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  value = aws_launch_template.app.id
}

output "ec2_iam_role_arn" {
  value = aws_iam_role.ec2.arn
}

# ⚠️  Private key output – for DEMO purposes only!
# In production use AWS Secrets Manager or Vault to store & retrieve.
output "private_key_pem" {
  description = "EC2 SSH private key (DEMO ONLY – store in Vault in production)"
  value       = tls_private_key.app.private_key_pem
  sensitive   = true
}
