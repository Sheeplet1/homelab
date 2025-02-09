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
