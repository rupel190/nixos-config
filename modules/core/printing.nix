{ pkgs, ... }:
let
  printerMac = "98:6E:E8:47:89:65"; # PT-P710BT3062, paired 2026-09-08

  subst =
    replacements: file:
    builtins.replaceStrings (map (r: r.from) replacements) (map (r: r.to) replacements) (
      builtins.readFile file
    );

  # CUPS 2.4 ships no serial/file backend, so Bluetooth needs a backend of our own.
  cupsBluetoothBackend = pkgs.writeTextFile {
    name = "cups-backend-bluetooth";
    destination = "/lib/cups/backend/bluetooth";
    executable = true;
    text = subst [
      {
        from = "#!/usr/bin/env python3";
        to = "#!${pkgs.python3}/bin/python3";
      }
      {
        from = ''BLUETOOTHCTL = "bluetoothctl"'';
        to = ''BLUETOOTHCTL = "${pkgs.bluez}/bin/bluetoothctl"'';
      }
    ] ./ptouch/bluetooth-backend.py;
  };

  # `label "text"` — renders and speaks PT-CBP over RFCOMM, so labels are only as
  # long as their text. CUPS pins every label to the PPD's fixed 100mm page.
  ptouchLabel = pkgs.writeScriptBin "label" (
    subst [
      {
        from = "#!/usr/bin/env python3";
        to = "#!${pkgs.python3}/bin/python3";
      }
      {
        from = ''MAGICK = "magick"'';
        to = ''MAGICK = "${pkgs.imagemagick}/bin/magick"'';
      }
      {
        from = ''FCMATCH = "fc-match"'';
        to = ''FCMATCH = "${pkgs.fontconfig.bin}/bin/fc-match"'';
      }
      {
        from = ''FCLIST = "fc-list"'';
        to = ''FCLIST = "${pkgs.fontconfig.bin}/bin/fc-list"'';
      }
      {
        from = ''DEFAULT_MAC = ""'';
        to = ''DEFAULT_MAC = "${printerMac}"'';
      }
    ] ./ptouch/label.py
  );

  # Upstream PPDs declare ImageableArea "0 0 0 0", which makes the page transform
  # singular: poppler pdftops dies, Ghostscript clips every label to blank tape.
  ptouchDriverFixed = pkgs.runCommand "ptouch-driver-fixed-ppds" { } ''
    cp -r --no-preserve=mode,ownership ${pkgs.ptouch-driver} $out
    for f in "$out"/share/cups/model/ptouch-driver/*.ppd.gz; do
      gzip -cd "$f" \
        | ${pkgs.python3}/bin/python3 ${./ptouch/fix-ppd-imageable-area.py} \
        | gzip -c > "$f.new"
      mv "$f.new" "$f"
    done
  '';
in
{
  # Brother PT-P710BT label printer — Bluetooth RFCOMM ch 1 (USB 04f9:20af also wired up)
  services.printing = {
    enable = true;
    drivers = [
      ptouchDriverFixed
      cupsBluetoothBackend
    ];
  };

  # The queue is for images/PDFs from apps; `label` is the everyday path.
  hardware.printers.ensurePrinters = [
    {
      name = "PT-P710BT";
      description = "Brother PT-P710BT (Bluetooth)";
      deviceUri = "bluetooth://${builtins.replaceStrings [ ":" ] [ "-" ] printerMac}/1";
      model = "ptouch-driver/Brother-PT-P710BT-ptouch-pt.ppd.gz";
      ppdOptions.PageSize = "tz-12";
    }
  ];

  environment.systemPackages = [
    ptouchLabel
    pkgs.ptouch-print # USB-only CLI, kept in case a data cable turns up
  ];

  # uaccess must ship as a udev *package* (70-*) — extraRules lands at 99, too late for 73-seat-late
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "ptouch-udev-rules";
      destination = "/lib/udev/rules.d/70-ptouch-print.rules";
      text = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="04f9", ATTR{idProduct}=="20af", TAG+="uaccess"
      '';
    })
  ];
}
