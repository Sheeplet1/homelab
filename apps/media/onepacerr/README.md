# OnePacerr

OnePacerr manages the separate `One Pace` series in Jellyfin's `Anime` library. It shares `/data`
with Jellyfin and qBittorrent, allowing completed downloads to be hard-linked into the library.

## Credentials

The deployment reads the existing qBittorrent credentials and the following Jellyfin credentials
from `media-secrets`:

- `JELLYFIN_USERNAME`
- `JELLYFIN_PASSWORD`

Add the existing Jellyfin administrator credentials to an ignored plaintext file, then merge only
those keys into the existing SealedSecret:

```bash
kubectl create secret generic media-secrets \
  --namespace jellyfin-media \
  --from-literal=JELLYFIN_USERNAME='<username>' \
  --from-literal=JELLYFIN_PASSWORD='<password>' \
  --dry-run=client \
  --output yaml > apps/media/extras/secrets.yaml

kubeseal \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --merge-into apps/media/extras/sealedsecrets.yaml \
  --format yaml \
  < apps/media/extras/secrets.yaml
```

Delete the plaintext file after checking the sealed output. The repository ignores every
`secrets.yaml` file as a second line of defence.

## Rollout

The checked-in configuration starts in metadata-only mode. It updates NFO files and posters for
existing episodes, but does not rename files or submit torrents.

After validating the metadata in Jellyfin, perform the one-time reconciliation by setting these
values in `configmap.yaml`:

```yaml
PIPELINE_SKIP_VERIFY_PRESENT_FILES: "false"
PIPELINE_SKIP_ORGANIZE_PRESENT_FILES: "false"
PIPELINE_SKIP_DOWNLOADS: "false"
```

This verifies and organizes existing files, then queues every missing arc and special. Once the
reconciliation has completed, return the first two values to `"true"`. Leave downloads enabled and
`PIPELINE_SKIP_UPDATE_METADATA_PRESENT_FILES` set to `"false"` for steady-state operation. Restart
the pod after each ConfigMap change so the process receives the new environment values:

```bash
kubectl delete pod \
  --namespace jellyfin-media \
  --selector app.kubernetes.io/name=onepacerr
```

## Verification

Check the internal health and status APIs without publishing an ingress:

```bash
kubectl port-forward --namespace jellyfin-media service/onepacerr 3000:3000
curl http://127.0.0.1:3000/api/v1/healthz
curl http://127.0.0.1:3000/api/v1/status/pipeline
curl http://127.0.0.1:3000/api/v1/status/pipeline/report
curl http://127.0.0.1:3000/api/v1/status/metadata
```
