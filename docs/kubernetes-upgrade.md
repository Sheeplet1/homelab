# Kubernetes upgrade and recovery

The single server `homelab-0` runs NixOS 24.11. Its OS input stays on that
release for this engine upgrade; `nix/flake.lock` pins separate package inputs
for k3s. Keep `system.stateVersion = "24.05"`.

## Versioned stages

Run these stages in order. Every output retains the hostname `homelab-0`, the
existing datastore, service networks, storage paths, and disabled bundled ingress.

| Flake output         | k3s version    |
| -------------------- | -------------- |
| `homelab-0-k3s-1-31` | `1.31.8+k3s1`  |
| `homelab-0-k3s-1-32` | `1.32.13+k3s1` |
| `homelab-0-k3s-1-33` | `1.33.13+k3s2` |
| `homelab-0-k3s-1-34` | `1.34.11+k3s1` |
| `homelab-0`          | `1.35.8+k3s1`  |

Only the package input used for the intermediate 1.33 stage permits its exact
end-of-life package. Never skip a minor version. See the
[K3s upgrade guidance](https://docs.k3s.io/upgrades/manual).

## Preparation and publication

Commit only the engine configuration, lockfile, controller Application version
pins, and this runbook. Pending HTTPS values, certificate resources, DNS changes,
and HTTPS documentation must remain unpublished until the separate certificate
rollout. Existing ArgoCD applications read values from `main` automatically.

Before maintenance, verify SSH with sudo over the LAN, retain the current system
closure with a Nix GC root, record controller sources, replica counts and CronJob
suspension states, and save the ingress/service/PVC inventory. Do not use the
in-cluster WireGuard or Pi-hole services as the only recovery access path.

The live cluster uses embedded etcd. Before every engine or storage version change,
run `sudo k3s etcd-snapshot save --name <stage>` and copy the resulting snapshot
and `/var/lib/rancher/k3s/server/token` off the node. The token is confidential;
never print it or put it into Git or the Nix store.

Store recovery artifacts under `/home/anthonyd/Backups/homelab/<run>/` on the
workstation with directory mode 0700 and file mode 0600. Verify transfer checksums.
Also back up `/etc/nixos` and the Sealed Secrets controller keys without printing
their contents. Etcd snapshots contain Kubernetes Secrets but not application
volume contents.

Pause ArgoCD reconciliation and scheduled application jobs before stopping
stateful applications. Record the original settings for restoration. Wait until
Longhorn volumes are detached before taking a cold copy of `/var/lib/longhorn`
with sparse files, ownership, ACLs and extended attributes preserved. Back up all
eleven volumes, including detached volumes. The bulk media filesystem at `/storage`
is outside this upgrade and is not included in the application-state backup.
Require a verified off-node copy before modifying storage versions.

## Upgrade sequence

1. Correct the Gluetun volume's replica count from three to one, matching the
   single storage node. Preserve existing PVCs, PVs, and replica data.
2. Upgrade the existing NGINX installation to chart 4.15.1 with its current HTTP
   values and LoadBalancer address. Its controller supports Kubernetes 1.31–1.35.
3. Upgrade Longhorn 1.8.0 → 1.8.2 → 1.9.2, waiting for manager, CSI and volume
   engine upgrades at each step. Use the existing live storage settings during
   these stages; do not attempt an in-place mutation of StorageClass parameters.
4. Build and activate `homelab-0-k3s-1-32` through NixOS. Then upgrade Longhorn
   1.9.2 → 1.10.2 → 1.11.3, completing each engine upgrade before proceeding.
5. Activate `homelab-0-k3s-1-33`, then `homelab-0-k3s-1-34`, then `homelab-0`.
   Build before activating, and verify every stage before continuing.

For an output named `<stage>`, build from the isolated upgrade checkout:

```sh
nix build ./nix#nixosConfigurations.<stage>.config.system.build.toplevel
sudo nix-env --profile /nix/var/nix/profiles/system --set ./result
sudo ./result/bin/switch-to-configuration switch
```

Record each previous system closure and its matching snapshot. Compare the built
system against the running configuration before switching. Stop if unrelated host
changes or incompatible storage settings would be activated. Do not drain the only
node using the default Longhorn last-replica protection; there is no second node
to receive workloads. Expect maintenance downtime, including DNS and VPN outages.

After every stage, require a Ready node, successful `/readyz`, healthy Longhorn
controllers, expected volume attachment state, and no new scheduling or mount
errors. Restore workloads and reconciliation from the saved state, verify HTTP
ingress, DNS, WireGuard and application reads/writes, and check the replica count
and CLI version. Previously unused detached volumes may remain detached.

Only after Kubernetes reports `v1.35.8+k3s1` and application checks pass should
the separate HTTPS rollout in `docs/https.md` resume.

## Recovery

A Git revert reproduces configuration; it does not reverse datastore migrations.
Rolling back a Kubernetes minor requires both the older system closure and an
etcd snapshot taken on that minor. See
[K3s rollback](https://docs.k3s.io/upgrades/roll-back) and
[snapshot restore](https://docs.k3s.io/cli/etcd-snapshot).

Keep reconciliation and application writers stopped during recovery. Stop k3s,
select the recorded older system closure without starting its service, and run
that closure's matching k3s binary with `server --cluster-reset
--cluster-reset-restore-path=<snapshot> --token-file
/var/lib/rancher/k3s/server/token`. Restore the matching token first and retain
the failed state for diagnosis. Once reset completes, activate the older system
and verify cluster health before restoring application writers.

Longhorn schema and engine upgrades need their matching storage recovery state;
do not assume changing the chart pin downgrades them safely. Restore the paired
datastore and cold volume backup if recovery crosses a Longhorn upgrade. Test
restoration using copies, and retain backups until both the engine upgrade and
the later HTTPS rollout have been accepted.
