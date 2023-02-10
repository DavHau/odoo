{config, lib, drv-parts, ...}: let

  l = lib // builtins;
  t = l.types;

in {

  options = {

    pythonSources = l.mkOption {
      type = t.package;
      description = ''
        A package that contains fetched python sources.
        Each single python source must be located ina subdirectory named after the package name.
      '';
    };

    substitutions = l.mkOption {
      type = t.attrsOf t.package;
      description = ''
        Substitute individual python packages from nixpkgs.
      '';
    };

    sdistDeps = l.mkOption {
      type = t.functionTo (t.attrsOf (t.listOf (t.oneOf [t.package t.path])));
      description = ''
        Define extra python buildInputs for sdist package builds
      '';
    };

    overrides = l.mkOption {
      type = t.attrsOf (t.functionTo t.attrs);
      description = ''
        Overrides for sdist package builds
      '';
    };
  };
}
