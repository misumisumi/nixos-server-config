{
  inputs,
  overlay,
  stateVersion,
  ...
}:
# Multipul arguments
let
  lib = inputs.nixpkgs.lib;
  settings = {
    hostname,
    rootDir ? "",
  }: let
    system = "x86_64-linux";
    pkgs-stable = import inputs.nixpkgs-stable {
      inherit system;
      config = {allowUnfree = true;};
    };
  in
    with lib;
      nixosSystem {
        inherit system;
        specialArgs = {
          inherit hostname inputs stateVersion;
          user = hostname;
        }; # specialArgs give some args to modules
        modules = [
          ./hosts/common
          (overlay {
            inherit (inputs) nixpkgs;
            inherit pkgs-stable;
          })

          (./. + "/${rootDir}") # Each machine conf
        ];
      };
in {
  alice = settings {
    hostname = "alice";
    rootDir = "hosts/alice";
  };
  strea = settings {
    hostname = "strea";
    rootDir = "hosts/strea";
  };
  yui = settings {
    hostname = "yui";
    rootDir = "hosts/yui";
  };
  lxc-container = with lib;
    nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit stateVersion inputs;};
      modules = [
        ./cluster/init/ssh.nix
        ./cluster/init/system.nix
        inputs.lxd-nixos.nixosModules.container
      ];
    };
  lxc-virtual-machine = with lib;
    nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit stateVersion inputs;};
      modules = [
        ./cluster/init/ssh.nix
        ./cluster/init/system.nix
        inputs.lxd-nixos.nixosModules.virtual-machine
      ];
    };
}