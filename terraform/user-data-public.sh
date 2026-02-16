#!/bin/bash
set -eux
apt-get update -y
apt-get install -y docker.io
systemctl enable --now docker

docker run -d --name mapserver -p 80:80 \
  --restart unless-stopped \
  camptocamp/mapserver
