{ pkgs, username, ... }:
let
  dev = "eno1";
  # ~70% of the ~11.5 Mbit/s uplink (speedtest 2026-10-08), so the first Proton upload doesn't swamp it
  rate = "8mbit";
  mark = "0x70";
  rule = "OUTPUT -m owner --gid-owner proton-mirror -j MARK --set-mark ${mark}";
in
{
  # proton-mirror runs its uploads as this group (sg); its packets get marked and capped below
  users.groups.proton-mirror = { };
  users.users.${username}.extraGroups = [ "proton-mirror" ];

  networking.firewall.extraCommands = ''
    for ipt in iptables ip6tables; do
      $ipt -t mangle -D ${rule} 2>/dev/null || true
      $ipt -t mangle -A ${rule}
    done
  '';
  networking.firewall.extraStopCommands = ''
    for ipt in iptables ip6tables; do $ipt -t mangle -D ${rule} 2>/dev/null || true; done
  '';

  # htb: everything else stays at line rate with fq_codel; marked traffic gets its own capped class
  systemd.services.backup-shaper = {
    description = "Cap the Proton mirror's upload on ${dev}";
    wantedBy = [ "multi-user.target" ];
    bindsTo = [ "sys-subsystem-net-devices-${dev}.device" ];
    after = [ "sys-subsystem-net-devices-${dev}.device" ];
    path = [ pkgs.iproute2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.iproute2}/bin/tc qdisc del dev ${dev} root";
    };
    script = ''
      tc qdisc replace dev ${dev} root handle 1: htb default 10
      tc class replace dev ${dev} parent 1: classid 1:1 htb rate 10gbit
      tc class replace dev ${dev} parent 1:1 classid 1:10 htb rate 10gbit
      tc class replace dev ${dev} parent 1:1 classid 1:20 htb rate ${rate} ceil ${rate}
      tc qdisc replace dev ${dev} parent 1:10 fq_codel
      tc qdisc replace dev ${dev} parent 1:20 fq_codel
      tc filter replace dev ${dev} parent 1: protocol all prio 1 handle ${mark} fw flowid 1:20
    '';
  };
}
