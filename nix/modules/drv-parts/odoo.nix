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
  #   those were hard to fix
  substitutions = {
    python-ldap = python.pkgs.python-ldap;
    pillow = python.pkgs.pillow;
  };

  # Only for sdist deps we need to specify the dependencies, because this
  #   is required in order to build wheels for them.
  sdistDeps = wheels: (with wheels; {
    vobject = [
      python-dateutil
      six
    ];
    ebaysdk = [
      certifi
      chardet
      idna
      lxml
      requests
      urllib3
    ];
    libsass = [
      six
    ];
    ofxparse = [
      beautifulsoup4
      lxml
      six
      soupsieve
    ];
  });

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
