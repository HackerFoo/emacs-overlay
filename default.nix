self: super:
let

  mkExDrv = emacsPackages: name: args: let
    repoMeta = super.lib.importJSON (./repos/exwm/. + "/${name}.json");
  in emacsPackages.melpaBuild (args // {
    pname   = name;
    ename   = name;
    version = repoMeta.version;
    recipe  = builtins.toFile "recipe" ''
      (${name} :fetcher github
      :repo "ch11ng/${name}")
    '';

    src = super.fetchFromGitHub {
      owner  = "ch11ng";
      repo   = name;
      inherit (repoMeta) rev sha256;
    };
  });

  emacsGit = let
    repoMeta = super.lib.importJSON ./repos/emacs/emacs-master.json;
  in (self.emacs.override { srcRepo = true; }).overrideAttrs(old: {
    name = "emacs-git-${repoMeta.version}";
    inherit (repoMeta) version;
    src = super.fetchFromGitHub {
      owner = "emacs-mirror";
      repo = "emacs";
      inherit (repoMeta) sha256 rev;
    };
    buildInputs = old.buildInputs ++ [ super.jansson super.harfbuzz.dev ];
    patches = [
      ./patches/tramp-detect-wrapped-gvfsd.patch
      ./patches/clean-env.patch
    ];
    postPatch = ''
       substituteInPlace lisp/loadup.el \
         --replace '(emacs-repository-get-version)' '"${repoMeta.rev}"' \
         --replace '(emacs-repository-get-branch)' '"master"'
    '';
  });

  emacsUnstable = let
    repoMeta = super.lib.importJSON ./repos/emacs/emacs-unstable.json;
  in (self.emacs.override { srcRepo = true; }).overrideAttrs(old: {
    name = repoMeta.version;
    inherit (repoMeta) version;
    src = super.fetchFromGitHub {
      owner = "emacs-mirror";
      repo = "emacs";
      inherit (repoMeta) sha256 rev;
    };
    buildInputs = old.buildInputs ++ [ super.jansson super.harfbuzz.dev ];
    patches = [
      ./patches/tramp-detect-wrapped-gvfsd-27.patch
      ./patches/clean-env.patch
    ];
  });


in {
  inherit emacsGit emacsUnstable;

  emacsGit-nox = ((emacsGit.override {
    withX = false;
    withGTK2 = false;
    withGTK3 = false;
  }).overrideAttrs(oa: {
    name = "${oa.name}-nox";
  }));

  emacsUnstable-nox = ((emacsUnstable.override {
    withX = false;
    withGTK2 = false;
    withGTK3 = false;
  }).overrideAttrs(oa: {
    name = "${oa.name}-nox";
  }));

  emacsWithPackagesFromUsePackage = import ./elisp.nix { pkgs = self; };

  emacsPackagesFor = emacs: (
    (super.emacsPackagesFor emacs).overrideScope'(eself: esuper: let

      melpaStablePackages = esuper.melpaStablePackages.override {
        archiveJson = ./repos/melpa/recipes-archive-melpa.json;
      };

      melpaPackages = esuper.melpaPackages.override {
        archiveJson = ./repos/melpa/recipes-archive-melpa.json;
      };

      elpaPackages = esuper.elpaPackages.override {
        generated = ./repos/elpa/elpa-generated.nix;
      };

      # Note: Org generation is currently failing (probably a bug in emacs2nix)
      # Comment this out when a fix has reached unstable
      # orgPackages = esuper.orgPackages.override {
      #   generated = ./repos/org/org-packages.nix
      # }

      epkgs = esuper.override {
        inherit melpaStablePackages melpaPackages elpaPackages;
      };

    in epkgs // {
      xelb = mkExDrv eself "xelb" {
        packageRequires = [ eself.cl-generic eself.emacs ];
      };

      exwm = mkExDrv eself "exwm" {
        packageRequires = [ eself.xelb ];
      };
    }));

}
