# Local HTTPS with DuckDNS

Services use `https://<service>.sheeplet.duckdns.org`. Pi-hole resolves these names to
the ingress controller at `192.168.50.2`. cert-manager proves control through public
DuckDNS TXT records and renews one wildcard certificate. No new router port forwards
or public address updater are required.

## Existing application connections

A read-only audit of the running media applications found that their internal
connections already use Kubernetes service names. These connections do not depend
on the ingress hostnames and need no settings changes for the HTTPS migration.

| Application       | Destination       | Existing address                     |
| ----------------- | ----------------- | ------------------------------------ |
| Sonarr and Radarr | qBittorrent       | `http://qbittorrent:8080`            |
| Sonarr and Radarr | Prowlarr indexers | `http://prowlarr:9696/<indexer-id>/` |
| Prowlarr          | Sonarr            | `http://sonarr:8989`                 |
| Prowlarr          | Radarr            | `http://radarr:7878`                 |
| Prowlarr          | qBittorrent       | `http://qbittorrent:8080`            |
| Prowlarr          | FlareSolverr      | `http://flaresolverr:8191/`          |
| Jellyseerr        | Sonarr            | `http://sonarr:8989`                 |
| Jellyseerr        | Radarr            | `http://radarr:7878`                 |
| Jellyseerr        | Jellyfin          | `http://jellyfin:8096`               |

Configarr and Onepacerr also use service names in their repository configuration.
The audit found no `sheeplet.com` references in the inspected Sonarr, Radarr, and
Prowlarr connection fields, Jellyseerr settings, qBittorrent configuration, or
Jellyfin network and system configuration. HTTP requests from Jellyseerr to Sonarr,
Radarr, Prowlarr, qBittorrent, and Jellyfin all reached their services; responses were
200 or 302. No running application settings were changed.

Do not add permanent HTTP aliases for every old ingress hostname. Repeat the
connection check before cutover if application settings have changed since this
audit. Saved URLs in browsers, phones, and other clients outside the cluster still
need to move to the DuckDNS HTTPS addresses.

If a remaining client cannot migrate during cutover, add a temporary HTTP ingress
only for its required old hostname, using the same namespace, backend, paths, and
necessary proxy annotations as the service's primary ingress. Set both
`nginx.ingress.kubernetes.io/ssl-redirect` and
`nginx.ingress.kubernetes.io/force-ssl-redirect` to `"false"` on that ingress and omit
its TLS configuration. Record the dependent client and remove the alias once that
client has migrated. No such alias is currently required by the audited settings.

## Prerequisites

The cluster was upgraded to Kubernetes `1.35.8+k3s1` on 15 November 2026; see
[the upgrade and recovery record](kubernetes-upgrade.md).
The pinned cert-manager `1.21.3` supports Kubernetes `1.33` through `1.36`.
The Kubernetes prerequisite is satisfied. Recheck the running version and the
[cert-manager support matrix](https://cert-manager.io/docs/releases/) when upgrading.

```bash
kubectl get --raw /version
kubectl get service ingress-nginx-internal-controller -n nginx-system
```

Use a machine with cluster access for the rollout. The examples use the ArgoCD
CLI; a manual sync can also be requested through the Application API:

```bash
kubectl patch application cert-manager -n argocd --type=merge \
  -p '{"operation":{"sync":{"prune":false}}}'
```

Keep the
existing ingress controller and its address. Devices must use Pi-hole
(`192.168.50.50`) for local DNS; WireGuard clients already use this resolver.

## Token and applications

The existing `apps/networking/cert-manager/sealedsecrets.yaml` produces Secret
`cert-manager/cert-manager-secrets` with a `token` key. Its encrypted contents are
bound to that name and namespace. Keep that file when committing the new resources;
exclude `secrets.yaml` and temporary `.sealedsecrets.yaml*` files.

The plaintext token stays out of Helm values. To rotate it, follow
[the Sealed Secrets workflow](secrets.md) and preserve this Secret's identity.
Validate the sealed file against the target cluster before rollout:

```bash
kubeseal --validate --controller-name sealed-secrets \
  --controller-namespace kube-system \
  < apps/networking/cert-manager/sealedsecrets.yaml
```

The networking Kustomization registers three manually synced ArgoCD applications:
`cert-manager`, `duckdns-webhook`, and `cert-manager-config`. Manual sync is deliberate:
the adapter needs cert-manager's CRDs and serving certificates, and production
issuance follows a successful staging challenge. Parent Application sync waves alone
do not guarantee that these dependencies are ready.

## Staged rollout

Do not push all hostname and redirect changes before the production certificate is
ready: existing service applications automatically sync values from `main`.
Publish this working tree in stages. First publish only the new certificate
applications, their values, certificate resources, sealed token, and networking
Kustomization entries. Keep existing service and NGINX values until step 4.

1. After the Kubernetes upgrade, register the applications using the existing
   networking bootstrap process (or `kubectl apply -k apps/networking`). Then sync
   cert-manager and wait for its deployments:

   ```bash
   argocd app sync cert-manager
   kubectl rollout status deployment/cert-manager -n cert-manager
   kubectl rollout status deployment/cert-manager-webhook -n cert-manager
   kubectl rollout status deployment/cert-manager-cainjector -n cert-manager
   argocd app sync duckdns-webhook
   kubectl rollout status deployment/duckdns-webhook-cert-manager-duckdns-webhook -n cert-manager
   kubectl wait --for=condition=Available \
     apiservice/v1alpha1.acme.sheeplet.duckdns.org --timeout=180s
   ```

2. Apply the staging overlay before syncing `cert-manager-config`. This creates the
   same wildcard Certificate with the staging issuer and a separate staging Secret:

   ```bash
   kubectl apply -k apps/networking/cert-manager-staging
   kubectl wait --for=condition=Ready certificate/sheeplet-wildcard \
     -n nginx-system --timeout=600s
   ```

   A staging certificate is deliberately untrusted. Never configure NGINX to use
   `sheeplet-wildcard-staging-tls`. Request only the wildcard: DuckDNS shares one TXT
   value across the subdomain, so concurrent challenges can overwrite one another.
   The bare name `sheeplet.duckdns.org` is not covered or used as an application URL.

3. Sync `cert-manager-config` to switch the Certificate to the production issuer.
   Wait for the production Secret, then the Certificate readiness condition:

   ```bash
   argocd app sync cert-manager-config
   kubectl wait --for=create secret/sheeplet-wildcard-tls \
     -n nginx-system --timeout=600s
   kubectl wait --for=condition=Ready certificate/sheeplet-wildcard \
     -n nginx-system --timeout=600s
   ```

4. Publish NGINX's `controller.extraArgs.default-ssl-certificate` setting and the
   Homepage hostname first. Hold `controller.config.force-ssl-redirect` and the
   remaining hostname changes for step 5. Test Homepage over HTTPS using the commands
   below; the default certificate supports HTTPS without an ingress TLS Secret.

5. Publish the remaining service hostname and dashboard changes, Actual Budget's
   default-certificate TLS configuration, and Pi-hole's new admin hostname. Confirm
   ExternalDNS has populated the new names, then publish the global
   `force-ssl-redirect` setting. Existing streaming and upload annotations stay intact.

ExternalDNS uses `upsert-only`, so old local DNS records may remain after migration.
Retain any record backing an explicitly documented temporary HTTP alias. Remove
other obsolete `sheeplet.com` and `pihole.home` entries from Pi-hole after clients and
bookmarks have migrated. Those names are outside the new certificate, and a stale
DNS record alone does not preserve an ingress route.

## Verification and renewal

```bash
nslookup homepage.sheeplet.duckdns.org 192.168.50.50
curl --resolve homepage.sheeplet.duckdns.org:443:192.168.50.2 \
  https://homepage.sheeplet.duckdns.org
curl -I http://homepage.sheeplet.duckdns.org
kubectl get certificate sheeplet-wildcard -n nginx-system \
  -o jsonpath='{.status.renewalTime}{"\n"}'
```

Expect DNS to return `192.168.50.2`, HTTPS to validate without bypassing trust checks,
and HTTP to redirect to the matching HTTPS URL after step 5. Repeat in a browser on
LAN and WireGuard, and check Jellyfin playback, Actual Budget access, and ArgoCD login.
Applications managed outside this repository may also need their saved base URLs
updated.

cert-manager updates the production Secret on renewal; NGINX watches it and loads
the replacement certificate. After renewal, inspect the certificate served by NGINX:

```bash
openssl s_client -connect 192.168.50.2:443 \
  -servername homepage.sheeplet.duckdns.org </dev/null 2>/dev/null \
  | openssl x509 -noout -serial -dates -ext subjectAltName
```

If issuance stalls, inspect `kubectl describe certificate sheeplet-wildcard -n
nginx-system`, `kubectl get challenges,orders -n nginx-system`, and the cert-manager
and DuckDNS webhook logs. Public resolvers must see `_acme-challenge` TXT values;
Pi-hole's local A records do not validate a certificate.

For rollback, revert the service values and NGINX certificate/redirect settings
together. Keep the certificate resources while diagnosing the issue; reverting a
hostname alone cannot make the new wildcard certificate valid for an old name.

## Completed rollout: 15 November 2026

Staging issuance succeeded before production issuance. The production wildcard
is trusted by the system CA store, expires on 13 February 2027, and has renewal
scheduled for 14 January 2027 (UTC). NGINX serves the production Secret
`nginx-system/sheeplet-wildcard-tls`; the staging Secret is not used by ingress.
All three certificate Applications remain manually synced. Certificate renewal
continues automatically through cert-manager.

The changes were published in gated commits:

| Commit    | Change                                                |
| --------- | ----------------------------------------------------- |
| `feda228` | Certificate infrastructure and manual bootstrap       |
| `6c07664` | Trusted Homepage canary and NGINX default certificate |
| `c43b7a9` | Service hostnames and dashboard links                 |
| `2729811` | Preserve removed Sonarr and Jellyseerr chart releases |
| `4075bad` | Global HTTP-to-HTTPS redirects                        |

Homepage's missing Application was registered against its existing resources.
ArgoCD's domain was updated with Helm chart 9.4.1 and its existing release values.
Only qBittorrent's inline ingress override was removed so its repository hostname
can reconcile; its VPN configuration was preserved. Sonarr and Jellyseerr retain
their installed versions through the [preserved charts](../apps/media/charts/README.md).
Server-side dry runs confirmed their application, service, volume, and monitoring
specifications were unchanged apart from the intended ingress hosts.

All eleven deployed service names resolve through Pi-hole to `192.168.50.2`.
Their HTTPS entry URLs pass normal trust verification, and HTTP redirects with
status 308 to the corresponding HTTPS entry URL:

| Service       | HTTPS entry URL                             |
| ------------- | ------------------------------------------- |
| Homepage      | <https://homepage.sheeplet.duckdns.org>     |
| ArgoCD        | <https://argocd.sheeplet.duckdns.org>       |
| Actual Budget | <https://budget.sheeplet.duckdns.org>       |
| Pi-hole       | <https://pihole.sheeplet.duckdns.org/admin> |
| Jellyfin      | <https://jellyfin.sheeplet.duckdns.org>     |
| Jellyseerr    | <https://jellyseerr.sheeplet.duckdns.org>   |
| Sonarr        | <https://sonarr.sheeplet.duckdns.org>       |
| Radarr        | <https://radarr.sheeplet.duckdns.org>       |
| Prowlarr      | <https://prowlarr.sheeplet.duckdns.org>     |
| qBittorrent   | <https://qbittorrent.sheeplet.duckdns.org>  |
| FlareSolverr  | <https://flaresolverr.sheeplet.duckdns.org> |

Normal workstation DNS and trusted HTTPS access to Homepage passed. Actual Budget
returns `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`. The read-only integration inventory
still uses Kubernetes service addresses, and direct requests from Jellyseerr to
the six media services returned 200 or 302. All active pods were Ready, and the
certificate, ingress, and migrated service Applications were Synced and Healthy.

Miniflux, Linkding and monitoring values were updated for future use; their
Applications were not active and were not enabled by this rollout. Pre-existing
non-HTTPS reconciliation issues, including the Sealed Secrets chart repository
error, remain outside this migration; the running Sealed Secrets controller
successfully unsealed the DuckDNS token.

Rollback inventories, the before/after verification results, and protected TLS
and ACME-account recovery copies are stored on the workstation under
`/home/anthonyd/Backups/homelab/https-20261115T030208Z/`. Keep its directory mode
0700 and Secret backup file modes 0600. Plaintext tokens and temporary sealing
files were not committed.

Old DNS records were retained pending migration of external client settings and
bookmarks. No old-domain ingress aliases were added. Browser login, Jellyfin
playback, and access from a separate WireGuard client remain device acceptance
checks; those were not exercised from this workstation.
