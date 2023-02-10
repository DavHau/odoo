{config, lib, drv-parts, ...}: let

  l = lib // builtins;

  python = config.deps.python;

  sdistDeps = config.sdistDeps wheels;

  installWheelFiles = directories: ''
    mkdir -p ./dist
    for dep in ${toString directories}; do
      echo "dep: $dep"
      cp $dep/* ./dist/
      chmod -R +w ./dist
    done
  '';

  # Attributes we never want to copy from nixpkgs
  excludeNixpkgsAttrs = l.genAttrs
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
      l.filterAttrs
      (name: _: ! excludeNixpkgsAttrs ? ${name})
      nixpkgsAttrs;

  distFile = distDir:
    "${distDir}/${l.head (l.attrNames (builtins.readDir distDir))}";

  isWheel = l.hasSuffix ".whl";

  /*
  Ensures that a given file is a wheel.
  If an sdist file is given, build a wheel and put it in $dist.
  If a wheel is given, do nothing but return the path.
  */
  ensureWheel = name: distDir: let
    file = distFile distDir;
  in
    config.substitutions.${name}.dist or (
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
      preInstall = l.optionalString (sdistDeps ? ${pname})
        (installWheelFiles sdistDeps.${pname});
    });

    finalPackage = package.overridePythonAttrs config.overrides.${pname} or (_: {});
  in
    finalPackage.dist;

  # all fetched sources converted to wheels
  wheels =
    l.mapAttrs
    (name: _: ensureWheel name "${config.pythonSources}/${name}")
    (builtins.readDir config.pythonSources);

in {

  imports = [
    drv-parts.modules.drv-parts.mkDerivation
    ./interface.nix
  ];

  config = {

    deps = {nixpkgs, ...}: {
      inherit (nixpkgs)
        autoPatchelfHook
        fetchPythonRequirements
        ;
      python = nixpkgs.python38;
      manylinuxPackages = nixpkgs.pythonManylinuxPackages.manylinux1;
    };

    env = {
      pipInstallFlags = "--ignore-installed";
    };

    doCheck = false;
    dontPatchELF = true;

    preInstall = installWheelFiles (l.attrValues wheels);

    buildInputs = with config.deps; [
      manylinuxPackages
    ];

    final.derivation =
      config.deps.python.pkgs.buildPythonPackage
      config.final.derivation-args;
  };
}
