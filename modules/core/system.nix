{
  self,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  nixpkgs.overlays = [
    inputs.millennium.overlays.default
    inputs.affinity-nix.overlays.default

    # catppuccin (python) 2.5.0 sweeps its optional matplotlib integration into
    # nativeCheckInputs + pythonImportsCheck, so `import catppuccin` runs at build
    # time and calls the now-removed matplotlib.style.core API → build crash, which
    # breaks catppuccin-gtk (used in modules/home/gtk.nix). matplotlib is only an
    # extra (never a runtime dep, and catppuccin-gtk doesn't use it), so drop it.
    (final: prev: {
      pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
        (pyfinal: pyprev: {
          catppuccin = pyprev.catppuccin.overridePythonAttrs (_: {
            # Skip the check phase: catppuccin 2.5.0's tests/test_matplotlib.py
            # hard-imports matplotlib, and its integration calls the removed
            # matplotlib.style.core API. matplotlib is only a check input (never a
            # runtime dep), so dropping checks lets catppuccin-gtk build cleanly.
            doCheck = false;
          });
        })
      ];
    })

    # gdal 3.13.1's autotest suite has one failing test in this nixpkgs pin:
    # gdrivers/zarr_driver.py::test_zarr_read_simple_sharding asserts that a
    # `zarr.json.gmac` tile-presence cache sidecar is written after opening a
    # sharded Zarr with CACHE_TILE_PRESENCE=YES — it isn't, so pytestCheckHook
    # fails the whole build. gdal fails identically on Hydra, so gdal-minimal is
    # never cached and gets rebuilt (and re-fails) locally, blocking the closure
    # pdal -> vtk -> freecad -> home-manager -> system. Append the one test to the
    # existing `disabledTests` allowlist (idiomatic, keeps the other ~18.7k tests).
    # Overriding base `gdal` propagates through the fixed point into `gdalMinimal`
    # (= gdal.override { useMinimalFeatures = true; }) and vtk's inline minimal
    # override, so this single entry covers every path. Drop on the next bump that
    # fixes the test upstream.
    (final: prev: {
      gdal = prev.gdal.overrideAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_zarr_read_simple_sharding"
        ];
      });
    })

    # pdal 2.9.3 doesn't compile against gdal 3.13.1 (same pin): recent gdal made
    # GDALDataset::GetMetadata() return CSLConstList (const char* const*) instead
    # of char**, and pdal's Raster::getMetadata still assigns it to a plain char**
    # -> "invalid conversion ... [-fpermissive]" hard error, which sinks the whole
    # closure (vtk -> freecad -> home-manager -> system). The pointer is read-only
    # ("// m_ds owns this"), so the correct upstream fix is to declare it const;
    # retype the one declaration to match. --replace-fail makes the build error out
    # (instead of silently no-op'ing) once a pdal bump changes this line = remove me.
    (final: prev: {
      pdal = prev.pdal.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace pdal/private/gdal/Raster.cpp \
            --replace-fail "char **papszMetadata = NULL;" "CSLConstList papszMetadata = NULL;"
        '';
      });
    })

    # Same gdal 3.13.1 CSLConstList break, third victim: vtk 9.5.2's GDAL raster
    # reader assigns GDALGetMetadata() (now returns CSLConstList = const char* const*)
    # to char** at two spots in IO/GDAL/vtkGDALRasterReader.cxx (lines 185, 881),
    # both read-only (CSLCount + iterate). vtk's IO/GDAL failure is what actually
    # sank the build — it was hidden behind FiltersCore in the parallel-make output.
    # Retype both to CSLConstList (NOT line 733's GetCategoryNames(), which still
    # returns char** and compiles fine). Overriding base `vtk` propagates through the
    # fixed point into the Qt/python variants freecad pulls. Remove on the bump that
    # const-corrects vtk upstream (--replace-fail will error to remind us).
    (final: prev: {
      vtk = prev.vtk.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace IO/GDAL/vtkGDALRasterReader.cxx \
            --replace-fail \
              "char** papszMetaData = GDALGetMetadata(this->GDALData, nullptr);" \
              "CSLConstList papszMetaData = GDALGetMetadata(this->GDALData, nullptr);" \
            --replace-fail \
              "char** papszMetadata = GDALGetMetadata(this->Impl->GDALData, domain.c_str());" \
              "CSLConstList papszMetadata = GDALGetMetadata(this->Impl->GDALData, domain.c_str());"
        '';
      });
    })
  ];

  # imports = [ inputs.nix-gaming.nixosModules.default ];
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-gaming.cachix.org"
        "https://cache.garnix.io" # affinity-nix prebuilt wine prefix
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    wget
    git
    pkgs.ragenix
    affinity-v3 # unified Affinity suite via affinity-nix (wine); needs your own installer on first run
  ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    # Catppuccin Macchiato palette for the Linux TTY (and therefore the tuigreet login).
    # Matches the macchiato cursor theme used in Hyprland. 16 entries, hex without '#':
    # normal 0-7 then bright 8-15. Index 0 (base #24273a) doubles as the console
    # background, giving the dark Catppuccin backdrop.
    colors = [
      "24273a" "ed8796" "a6da95" "eed49f" "8aadf4" "f5bde6" "8bd5ca" "b8c0e0"
      "5b6078" "ed8796" "a6da95" "eed49f" "8aadf4" "f5bde6" "8bd5ca" "a5adcb"
    ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    # Temporarily allow insecure qtwebengine for Qt5 apps
    # TODO: Identify which package needs this and find alternative
    # Likely culprits: teamspeak3, cryptomator, protonvpn-gui, keepassxc, digikam
    permittedInsecurePackages = [
      "qtwebengine-5.15.19"
    ];
  };

  system.stateVersion = "25.05";
}
