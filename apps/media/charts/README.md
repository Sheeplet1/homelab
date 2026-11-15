# Preserved media chart releases

These packages preserve the installed Sonarr 4.0.16 and Jellyseerr 3.0.1 charts.
The upstream public Helm index retains newer releases and removed both archives,
which prevented ArgoCD from reconciling HTTPS hostname changes.

Both charts were rebuilt from
[`loeken/helm-charts` at `a0bf371f3f8b28d0dd7a199e8feff273d7f55e50`](https://github.com/loeken/helm-charts/tree/a0bf371f3f8b28d0dd7a199e8feff273d7f55e50/charts),
with their declared `common` dependency pinned to 4.6.2 and included in each
package. Upstream chart contents and embedded dependency notices are retained.
The container versions remain `loeken/sonarr:4.0.16` and
`loeken/jellyseerr:3.0.1`.

Server-side dry runs confirmed the same Deployment, Service, PVC and ServiceMonitor
specifications as the live services. Only the intended ingress hostname differed.
The Application value files remain in `apps/media/values`.

To rebuild from that source checkout, resolve each chart's dependencies with the
`https://bjw-s-labs.github.io/helm-charts` Helm repository, then run:

```sh
helm package <source>/charts/sonarr --destination apps/media/charts
helm package <source>/charts/jellyseerr --destination apps/media/charts
helm repo index apps/media/charts \
  --url https://raw.githubusercontent.com/Sheeplet1/homelab/main/apps/media/charts
```

The index records package digests. Treat application or chart upgrades as separate
changes and repeat rendering and live-specification comparisons before publishing.
