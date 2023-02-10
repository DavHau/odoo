{config, lib, ...}: let
  l = lib // builtins;
  python = config.deps.python;

in {

  imports = [
    ./mach-nix-xs
  ];

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) postgresql;
  };

  pname = "odoo";
  version = "16.0";

  pythonSources = config.deps.fetchPythonRequirements {
    inherit (config.deps) python;
    requirementsFiles = [(../../../requirements.txt)];
    hash = "sha256-4ZdbcWXylNzfqhkOu2Gn2i7TOCUU3/TwLkPZ+E5vV2E=";
    maxDate = "2023-01-01";
    nativeBuildInputs = (with config.deps; [
      postgresql
    ]);
  };

  # Replace some python packages entirely with candidates from nixpkgs, because
  #   they are hard to fix
  substitutions = {
    python-ldap = python.pkgs.python-ldap;
    pillow = python.pkgs.pillow;
  };

  # fix some builds via overrides
  overrides = {
    libsass = old: {
      doCheck = false;
    };
    pypdf2 = old: {
      doCheck = false;
    };
  };
}
