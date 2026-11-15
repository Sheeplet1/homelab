{
  description = "Homelab NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    k3s-legacy.url = "github:NixOS/nixpkgs/b6018f87da91d19d0ab4cf979885689b469cdd41";
    k3s-packages.url = "github:NixOS/nixpkgs/f1e5c356f35d07e7b71a6b5e6c9338e0b029e0c0";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      legacy = import inputs.k3s-legacy { inherit system; };
      packages = import inputs.k3s-packages {
        inherit system;
        # Kubernetes upgrades must pass through 1.33 despite its end-of-life status.
        config.permittedInsecurePackages = [ "k3s-1.33.13+k3s2" ];
      };
      mkHost =
        package:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs.meta.hostname = "homelab-0";
          modules = [
            disko.nixosModules.disko
            ./disko-config.nix
            ./hardware-configuration.nix
            ./configuration.nix
            { services.k3s.package = package; }
          ];
        };
    in
    {
      nixosConfigurations = {
        homelab-0 = mkHost packages.k3s_1_35;
        homelab-0-k3s-1-31 = mkHost nixpkgs.legacyPackages.${system}.k3s;
        homelab-0-k3s-1-32 = mkHost legacy.k3s_1_32;
        homelab-0-k3s-1-33 = mkHost packages.k3s_1_33;
        homelab-0-k3s-1-34 = mkHost packages.k3s_1_34;
      };
    };
}
