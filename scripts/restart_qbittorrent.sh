#!/usr/bin/env bash

# This script is used to restart the qBittorrent container due to ProtonVPN's
# port changing.

NAMESPACE="jellyfin-media"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=qbittorrent -o jsonpath='{.items[0].metadata.name}')
CONTAINER_NAME="qbittorrent"

if [ -z "$POD_NAME"]; then
    echo "Error: cannot find qBittorrent pod in '$NAMESPACE'"
    exit 1
fi

echo "Restarting $POD_NAME in $NAMESPACE..."
kubectl -n $NAMESPACE exec -it $POD_NAME -c $CONTAINER_NAME -- /bin/sh -c "kill 1"

echo "$CONTAINER_NAME has been restarted."
