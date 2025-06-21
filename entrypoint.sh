#!/bin/bash
chown grafana:grafana /secrets/client_secret 2>/dev/null || true
chmod 640 /secrets/client_secret 2>/dev/null || true
exec /run.sh
