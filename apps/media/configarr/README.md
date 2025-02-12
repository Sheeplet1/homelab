# SETUP

> alias k=kubectl

1. Deploy onto the cluster using Kustomize:

   > k apply -k .

2. If needed, manually create a job to create the quality profiles for Sonarr
   and Radarr:

   > k create job --from=cronjob/configarr configarr-manual-$(date +%s) -n jellyfin-media
