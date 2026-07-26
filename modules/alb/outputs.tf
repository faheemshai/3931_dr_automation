# ---------------------------------------------------------------
# modules/alb/outputs.tf
# ---------------------------------------------------------------

output "lb_id" {
  description = "ID of the IBM Cloud Application Load Balancer"
  value       = ibm_is_lb.this.id
}

output "lb_hostname" {
  description = "Hostname of the IBM Cloud Application Load Balancer"
  value       = ibm_is_lb.this.hostname
}

output "pool_id" {
  description = "ID of the LB back-end pool (used to attach VSI members)"
  value       = ibm_is_lb_pool.app.id
}

output "listener_id" {
  description = "ID of the HTTP listener"
  value       = ibm_is_lb_listener.http.id
}
