_GOAL_: To have shared data across Jellyfin pods.

> Currently, the problem is that PVCs can only be claimed once per PV. What's
> happening is that when a pod (i.e, Radarr), claims the PVCs for `media` and
> `config`, then another pod (i.e, Sonarr) cannot re-claim.

What I need to figure out is how to share a persistent volume across multiple
pods.

ORRRR i define the PVCs for each config, and data required. Instead of defining
persistence in the helm chart, i define what volumes/volumeMounts they should be
pointing towards.

The downside of this is that I had to create the pvcs and pv manually but this is
fine since I can use kustomize.

1. Create pvc and pv yaml files for each service
2. Add volume mounts and volumes to helmchart files

---

Not sure if Radarr is working yet. I should try to mount Jellyfin and figure
outhow to check if it works from there on.
