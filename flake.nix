{
  description = "Homelab NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    { self, nixpkgs }@inputs:
    let
      nodes = [
        "homelab-0"
      ];
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map (name: {
          name = name;
          value = nixpkgs.lib.nixosSystem {
            specialArgs = {
              meta = {
                hostname = name;
              };
            };
            system = "x86_64-linux";
            modules = [
              ./disko-config.nix
              ./hardware-configuration.nix
              ./configuration.nix
            ];
          };
        }) nodes
      );
    };
}
