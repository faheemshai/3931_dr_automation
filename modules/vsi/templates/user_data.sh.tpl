#!/bin/bash
# ---------------------------------------------------------------
# User Data – IBM Cloud VSI bootstrap
# Image  : ibm-centos-stream-9-amd64-17
# Profile: bxf-2x8  (Flex | 2 vCPU / 8 GB RAM)
# Region : ${ibm_region} / ${ibm_zone}
#
# Installs nginx and serves a basic status page showing:
#   - Project / environment (injected by Terraform)
#   - Instance number, hostname and private IP
# SSH key was provisioned via Vault Enterprise → ibm_is_ssh_key
# ---------------------------------------------------------------
set -euo pipefail

# ── System update + nginx install ────────────────────────────────
dnf update -y
dnf install -y nginx

# ── Discover instance identity ───────────────────────────────────
HOSTNAME=$(hostname -s)
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# ── Deploy basic web app page ─────────────────────────────────────
mkdir -p /usr/share/nginx/html

cat > /usr/share/nginx/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${project} | ${environment}</title>
  <style>
    body { font-family: sans-serif; max-width: 640px; margin: 60px auto; color: #1f2328; }
    h1   { border-bottom: 2px solid #3b82d4; padding-bottom: 8px; color: #3b82d4; }
    table{ border-collapse: collapse; width: 100%; }
    td   { padding: 8px 12px; border: 1px solid #e5e7eb; }
    td:first-child { font-weight: bold; background: #f7f8fa; width: 180px; }
    .badge { display: inline-block; background: #3b82d4; color: #fff;
             padding: 2px 10px; border-radius: 4px; font-size: 12px; }
    .vault { color: #7c5cd8; font-weight: bold; }
  </style>
</head>
<body>
  <h1>&#128274; ${project} Demo App <span class="badge">${environment}</span></h1>
  <p>SSH key provisioned via <span class="vault">HashiCorp Vault Enterprise</span>
     &rarr; IBM Cloud SSH key &rarr; VSI bootstrap.</p>
  <table>
    <tr><td>Project</td><td>${project}</td></tr>
    <tr><td>Environment</td><td>${environment}</td></tr>
    <tr><td>Instance #</td><td>${instance_num}</td></tr>
    <tr><td>Hostname</td><td>$HOSTNAME</td></tr>
    <tr><td>Private IP</td><td>$PRIVATE_IP</td></tr>
    <tr><td>Region / Zone</td><td>${ibm_region} / ${ibm_zone}</td></tr>
    <tr><td>Image</td><td>ibm-centos-stream-9-amd64-17</td></tr>
    <tr><td>Profile</td><td>bxf-2x8 (Flex | 2 vCPU / 8 GB)</td></tr>
    <tr><td>Secret source</td><td>Vault Enterprise &nbsp;&#8594;&nbsp; kv/terraform</td></tr>
  </table>
  <p style="margin-top:24px; font-size:12px; color:#57606a;">
    Managed by Terraform Enterprise &nbsp;|&nbsp; Secrets from Vault Enterprise
  </p>
</body>
</html>
HTML

# ── Health-check endpoint ─────────────────────────────────────────
cat > /usr/share/nginx/html/health <<'HEALTH'
OK
HEALTH

# ── nginx configuration ───────────────────────────────────────────
cat > /etc/nginx/conf.d/app.conf <<'NGINX'
server {
    listen       80 default_server;
    listen       [::]:80 default_server;
    server_name  _;
    root         /usr/share/nginx/html;
    index        index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
NGINX

# Remove the default nginx server block to avoid conflicts
rm -f /etc/nginx/conf.d/default.conf

# ── Enable and start nginx ────────────────────────────────────────
systemctl enable nginx
systemctl start nginx

echo "Bootstrap complete: ${project}-${environment} instance ${instance_num} (${ibm_zone})"
