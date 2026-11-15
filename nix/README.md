# Nix Configuration

Physical nodes are setup using NixOS for reproducibility and personal comfort.

## Requirements

- Nix package manager
- NixOS installed on bare metal
- Git

## Setup

1. Setup the bare metal node with NixOS flashed on a USB drive. Node should be
   powered on and booted into NixOS.
2. Run `passwd` and set the password. This will be used to run `nix-anywhere`
   to setup the node via SSH.
3. Get the IP address of the node by running `ipaddr`.
   - Note: The k3s token field will need to be changed to the actual token,
     which is located in Bitwarden for me.
4. Run the below command:

```bash
sudo nix run github:nix-community/nixos-anywhere \
--extra-experimental-features "nix-command flakes" \
-- -- flake '.#<choose-homelab-profile> nixos@<ip-address>'
```

`<choose-homelab-profile>` is a Nix configuration profile defined in `flake.nix`.

`<ip-address>` is the IP address from Step 3.

5. Set the static IP address for the new node in your router configuration.
6. Confirm that the cluster is running via `kubectl get nodes`.

## Rebuilding the configuration on the nodes

1. SSH into the node.
2. Clone the homelab repository
3. Run the below command in the directory of the flake to update the configuration.

```shell
sudo nixos-rebuild --flake .#<homelab-profile> switch
```

## Updating the configuration of a node

1. Copy the committed `nix` directory into an isolated directory on the node.
2. Keep `services.k3s.tokenFile` pointing at the existing runtime token file. Do not
   replace it with a literal token; that would expose the token in the Nix store.
3. Build and review the intended output before activating it with `nixos-rebuild`.

The default `homelab-0` output pins Kubernetes 1.35.8. For engine upgrades, follow
the intermediate outputs, backup gates, and recovery procedure in
[Kubernetes upgrade and recovery](../docs/kubernetes-upgrade.md). A Git revert
alone does not reverse Kubernetes datastore migrations.
