{ self, lib, inputs, ... }: {
  perSystem = { config, self', inputs', pkgs, ... }: let

    odoo-drv = lib.evalModules {
      modules = [
        ../drv-parts/odoo.nix
        {src = self.src;}
      ];
      specialArgs.dependencySets = {
        nixpkgs = pkgs;
      };
      specialArgs.drv-parts = inputs.drv-parts;
    };

    odoo = odoo-drv.config.final.derivation;

  in {
    packages = {
      inherit
        odoo
        ;
    };
  };
}
