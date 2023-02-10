{ self, lib, ... }: {
  perSystem = { config, self', inputs', pkgs, ... }: let

    # LIBRARY

    installWheelFiles = directories: ''
      mkdir -p ./dist
      for dep in ${toString directories}; do
        echo "dep: $dep"
        cp $dep/* ./dist/
        chmod -R +w ./dist
      done
    '';

    # Attributes we never want to copy from nixpkgs
    excludeNixpkgsAttrs = lib.genAttrs
      [
        "all"
        "args"
        "builder"
        "name"
        "pname"
        "version"
        "src"
        "propagatedBuildInputs"
        "outputs"
      ]
      (name: null);

    # Extracts derivation args from a nixpkgs python package.
    nixpkgsAttrsFor = pname: let
      nixpkgsAttrs =
        (python.pkgs.${pname}.overridePythonAttrs (old: {passthru.old = old;}))
        .old;
    in
      if ! python.pkgs ? ${pname}
      then {}
      else
        lib.filterAttrs
        (name: _: ! excludeNixpkgsAttrs ? ${name})
        nixpkgsAttrs;

    distFile = distDir:
      "${distDir}/${lib.head (lib.attrNames (builtins.readDir distDir))}";

    isWheel = lib.hasSuffix ".whl";

    /*
    Ensures that a given file is a wheel.
    If an sdist file is given, build a wheel and put it in $dist.
    If a wheel is given, do nothing but return the path.
    */
    ensureWheel = name: distDir: let
      file = distFile distDir;
    in
      substitutions.${name}.dist or (
        if isWheel file
        then distDir
        else mkWheel name file
      );

    mkWheel = pname: distFile: let
      nixpkgsAttrs =
        if isWheel distFile
        then {}
        else nixpkgsAttrsFor pname;
      package = python.pkgs.buildPythonPackage (nixpkgsAttrs // {
        inherit pname;
        version = "wheel";
        src = distFile;
        format = "setuptools";
        pipInstallFlags = "--find-links ./dist";

        # In case of an sdist src, install all deps so a wheel can be built.
        preInstall = lib.optionalString (sdistDeps ? ${pname})
          (installWheelFiles sdistDeps.${pname});
      });

      finalPackage = package.overridePythonAttrs overrides.${pname} or (_: {});
    in
      finalPackage.dist;

    # all fetched sources converted to wheels
    wheels =
      lib.mapAttrs
      (name: _: ensureWheel name "${deps}/${name}")
      (builtins.readDir deps);

    # PACKAGING

    python = pkgs.python38;

    deps = pkgs.fetchPythonRequirements {
      inherit python;
      requirementsFiles = [("${self + /requirements.txt}")];
      hash = "sha256-4ZdbcWXylNzfqhkOu2Gn2i7TOCUU3/TwLkPZ+E5vV2E=";
      maxDate = "2023-01-01";
      nativeBuildInputs = [
        pkgs.postgresql
      ];
    };

    substitutions = {
      python-ldap = python.pkgs.python-ldap;
      pillow = python.pkgs.pillow;
    };

    # Only for sdist deps we need to specify the dependencies, because this
    #   is required in order to build wheels for them.
    sdistDeps = with wheels; {
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

    odoo = python.pkgs.buildPythonPackage {
      pname = "odoo";
      version = "16.0";
      src = self.src;
      preInstall = installWheelFiles (lib.attrValues wheels);
      pipInstallFlags = "--ignore-installed";
      buildInputs =
        pkgs.pythonManylinuxPackages.manylinux1
        ++ lib.concatMap (whl: whl.dist.buildInputs or []) (lib.attrValues wheels)
        ++ [
          pkgs.postgresql
        ];
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      doCheck = false;
      dontPatchELF = true;
    };

  in {
    packages = {
      inherit
        deps
        odoo
        ;
    };
  };
}
