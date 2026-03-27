{ pkgs, ... }:
{
  # aria2 download manager with RPC daemon

  programs.aria2 = {
    enable = true;
    settings = {
      enable-rpc = true;
      max-concurrent-downloads = 20;
      dir = "/home/rupel/Downloads";
      input-file = "/home/rupel/.config/aria2/session.txt";
      save-session = "/home/rupel/.config/aria2/session.txt";
      save-session-interval = 30;
    };
  };

  # Install aria2tui - TUI frontend for aria2
  home.packages = with pkgs; let
    listpick = python3Packages.buildPythonPackage rec {
      pname = "listpick";
      version = "0.1.16.17";
      pyproject = true;

      src = python3Packages.fetchPypi {
        inherit pname version;
        sha256 = "sha256-r7bkIgKaZlODcG5h7fHH+qRV715TYMxHst4+wStq1qA=";
      };

      build-system = [ python3Packages.setuptools ];
      dependencies = with python3Packages; [
        wcwidth
        pyperclip
        toml
        dill
      ];
      doCheck = false;
    };

    aria2tui = python3Packages.buildPythonApplication rec {
      pname = "aria2tui";
      version = "0.1.11.12";
      pyproject = true;

      src = python3Packages.fetchPypi {
        inherit pname version;
        sha256 = "sha256-fyGj4r3G4jbqmBhaUY7UYvYpWPBMXnP3ay8ZtjUrPJU=";
      };

      build-system = [ python3Packages.setuptools ];
      dependencies = with python3Packages; [
        plotille
        requests
        tabulate
        toml
        numpy
        listpick
      ];
      doCheck = false;
    };
  in [
    aria2tui
  ];

  # Create systemd user service to run aria2 daemon
  systemd.user.services.aria2 = {
    Unit = {
      Description = "aria2 download manager daemon";
      After = [ "network.target" ];
    };

    Service = {
      Type = "forking";
      ExecStart = "${pkgs.aria2}/bin/aria2c -D --conf-path=%h/.config/aria2/aria2.conf";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # aria2tui configuration
  xdg.configFile."aria2tui/config.toml".text = ''
    # Connection settings for aria2 RPC daemon
    port = 6800
    url = "http://localhost"
    token = ""  # Add your RPC secret if you set one in aria2.conf

    # Editor for adding URIs (default opens with 'O' key)
    editor = "nvim"

    # File picker for selecting torrent files
    file_picker = "yazi"
  '';

  programs.fish.functions = {
    # Add download from clipboard
    da = {
      description = "Download add - add URL from clipboard to aria2";
      body = ''
        echo "$(wl-paste)" | aria2tui
      '';
    };

    # List active downloads
    dl = {
      description = "Download list - show aria2 downloads with TUI";
      body = ''
        aria2tui
      '';
    };
  };
}
