{ pkgs, ... }:
# Vicinae launcher <-> browser tab integration (Native Messaging host).
#
# The Vicinae browser addon (extension id firefox@vicinae.com) can't touch the
# vicinae-server unix socket directly -- browser extensions are sandboxed. It
# reaches the running `vicinae server` via a Native Messaging host named
# "com.vicinae.vicinae": Zen/Firefox fork/execs `vicinae-browser-link` over
# stdio, and that shim relays JSON to /run/user/$UID/vicinae/vicinae.sock.
#
# The browser only discovers the host if a manifest file named
# com.vicinae.vicinae.json exists in its native-messaging-hosts dir. Zen reads
# ~/.mozilla/native-messaging-hosts/ (same dir KeePassXC's manifest uses).
#
# The vicinae package DOES ship a Firefox manifest, but its `path` is rendered
# with a doubled $out prefix (packaging bug) -> points at a nonexistent binary,
# so the addon connects and immediately disconnects. We render our own manifest
# with the real libexec path; ${pkgs.vicinae} keeps it correct across bumps.
#
# force = true: replaces the hand-written test manifest that first proved the fix.
{
  home.file.".mozilla/native-messaging-hosts/com.vicinae.vicinae.json" = {
    force = true;
    text = builtins.toJSON {
      name = "com.vicinae.vicinae";
      description = "Vicinae Native Messaging Host";
      path = "${pkgs.vicinae}/libexec/vicinae/vicinae-browser-link";
      type = "stdio";
      allowed_extensions = [ "firefox@vicinae.com" ];
    };
  };
}
