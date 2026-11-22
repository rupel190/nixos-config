# Home network zones

Status: plan, nothing changed on the router yet. Router: Banana Pi BPI-R3 with OpenWrt at 10.0.0.1,
behind the FRITZ!Box 7632; `router-backup` saves its config weekly to `/mnt/backup`. Router changes
are made by hand (LuCI or `uci`), never from this repo.

## Today (read from the router 2026-11-22)

A *bridge* is a virtual switch inside the router: it joins ports and Wi-Fi radios into one network.
The router has two, and routes between them only where its firewall allows:

```
br-lan  lan1 lan2 lan3 lan4 sfp2 + Wi-Fi BananaPi, BananaPi_5G  → zone lan, 10.0.0.0/24
br-iot  Wi-Fi BananaPi_IoT only                                 → zone iot, 10.0.100.0/24

lan → internet  yes
iot → internet  yes (encrypted DNS on port 853 blocked, plain DNS forced to the router)
iot → lan       no
lan → iot       no
```

All DNS from lan and iot is redirected to the router, whose dnsmasq forwards to Pi-hole on the Pi
(2 `server=` lines).

Everything sits in lan; the iot network is empty:

```
10.0.0.10   raspi, wired on lan4        10.0.0.30   tv
10.0.0.20   amanita                     10.0.0.31   marantz
10.0.0.21   cordyceps                   10.0.0.40   fold3
10.0.0.225  dreame_vacuum (Wi-Fi)       10.0.0.41   iphone
10.0.0.241  Hue Bridge (MAC 00:17:88…, Philips; wired)
```

## Target

```
zone  who                          may start connections to
lan   PCs, laptop, phones          internet · dmz · iot
iot   Dreame, later other gadgets  internet only for devices that need their cloud; the Dreame none
dmz   the Pi                       internet · amanita:11434 (Ollama for paperless-gpt) · nothing else
```

Replies always come back (the firewall is stateful), so "lan may reach dmz" already covers the
browser, amanita's backup pull, Beszel, Gatus and ssh.

The Pi gets a zone of its own because it is the box that will answer the internet (SplitPro,
Paperless through a Cloudflare tunnel). Should an app there be broken into, the intruder sits in dmz
and reaches nothing in lan except that one Ollama port. This is not the FRITZ!Box "exposed host",
which forwards every internet port to one device; the tunnel needs no open port at all.

## Steps, in this order

1. **Dreame offline, through Valetudo.** The robot is a Dreame L40 Ultra (`r2492`), which Valetudo
   supports (Fastboot rooting with the Dreame Breakout PCB, seals intact). Until that PCB is done it
   keeps its internet, so its app works. Once Valetudo runs, it joins `BananaPi_IoT` from Valetudo's
   own Wi-Fi setup (no cloud needed) and a rule rejects iot → wan for its MAC
   (`70:c9:32:9f:0e:91`); lan → iot then only needs its web page. The Hue Bridge stays in lan: it is
   wired, and its app and updates want the cloud; moving it would need a router port in br-iot and
   mDNS/SSDP across zones for the app.
2. **lan → iot forwarding**, only once something in lan has to talk to a gadget there (Home Assistant).
3. **The Pi moves to NixOS** (`MIGRATION.md`), keeping 10.0.0.10: one change at a time.
4. **dmz:** lan4 leaves br-lan for a new br-dmz (10.0.50.0/24, the Pi at 10.0.50.10), a new zone
   with the rules above, and the router's DNS (`server=` lines, redirects) pointed at the new address.
   The address also changes in the repo, where each file defines it once (`hosts/amanita/health.nix`,
   `glance.nix`, `ollama-pi.nix`, `modules/home/wtf.nix`, `pihole-watch.nix`), on the Pi (Paperless
   `.env` and compose, SplitPro `.env` and compose), in the DHCP static lease and the `raspi` ssh
   entry. Once Gatus and the Beszel hub run on the Pi, dmz → lan also gets their checks and the agent
   port 45876.
5. **Logins in front of everything** that has none (Glance, Gatus, paperless-gpt).
6. **Internet route:** the Cloudflare tunnel from the Pi, outbound only.
