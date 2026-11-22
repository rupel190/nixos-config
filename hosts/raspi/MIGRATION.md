# raspi: Debian → NixOS

Status: **done 2026-11-22.** The Pi runs NixOS 26.05 from its SD card, data on the USB disk as
before (stage 2 below). Written the same day from an inventory of the Debian Pi (Raspberry Pi 5
Model B Rev 1.1, Debian 12, kernel 6.12.34+rpt-rpi-2712, root on a 64 GB SD card, data on a 1 TB WD
USB disk); what follows is the plan as carried out, with what each stage taught.

## Ground rules

1. **The data does not move.** Everything that matters lives on the USB disk (`/mnt/usbhdd`, ext4,
   UUID `d2c9cf26-b12d-4074-b9b3-4a5d450e34d8`). NixOS ends up on the SD card as before, but gets
   there through a USB stick (a Transcend 32 GB, `usb-JetFlash_Transcend_32GB_25JS7A52XU1KRC4M-0:0`):
   it runs from the stick first while the Debian card sits untouched, and only once it works is the
   Debian card saved as an image onto the USB disk and overwritten. amanita has no SD reader, so all
   writing happens on the Pi itself.
2. **Same software first, newer later.** Every app starts on NixOS with the exact image it runs
   today (digests below) on the same data folders, so no database migration runs during the switch
   and the old card can still read the data. Upgrades and native NixOS modules come afterwards, one
   service at a time, each with its own fresh backup.
3. **No switch without a tested restore.** Each app's backup is restored on amanita and checked by
   hand first (drills below). InvoiceNinja first: it is the one that must not lose a single invoice.

## What runs today

| Service | How | Data on the USB disk | Backup today | On NixOS |
| --- | --- | --- | --- | --- |
| InvoiceNinja | Docker, custom build in `apps/invoiceninja` (nginx, php, supervisor conf) | `volumes/mysql` 118 MB, `public` 209 MB, `storage` 30 MB, `.env` (holds `APP_KEY`: without it encrypted fields are lost) | root cron 02:00 `invoiceninja-backup.sh`: mysqldump + tar, tiered retention; Sun 03:00 `config-backup.sh` tars `.env`, compose, nginx/php conf | same containers, same digests, same folders; backups as systemd timers |
| Pi-hole | Docker `pihole/pihole:latest` | `apps/pihole` | weekly config tar | as is first, then AdGuard Home (native) as its own step |
| SplitPro | Docker: splitpro v2.1.6, postgres 17.7, mailpit v1.33.1 (cloudflared declared, not running) | `apps/splitpro/data` | rupel cron 02:15 pg_dump + files | as is (not in nixpkgs) |
| Paperless | Docker: paperless-ngx 3.3.2, redis, paperless-gpt v0.31.0 | `apps/paperless/data` | rupel cron 02:30 `document_exporter` → `backups/paperless` | native `services.paperless` (nixpkgs has 3.3.2), data copied |
| Beszel agent | Docker 0.21.0 | – | – | native, like `modules/core/beszel-agent.nix` |
| ZeroTier | Debian service | `/var/lib/zerotier-one` (identity: keep it, or the node gets a new address) | none | `services.zerotierone` with the old identity copied in |
| CUPS | Debian service, 127.0.0.1 only, no printer attached | – | – | drop (the Brother label printer works from the desktops, `modules/core/printing.nix`) |
| smartmontools | Debian service | – | – | `services.smartd` |
| ufw | 22, 53, 443, 8080, 30814/udp, 8083 (old), 45876 from amanita | – | – | `networking.firewall` |
| `/var/log` | bind-mounted onto `/mnt/usbhdd/logs/var-log` to spare the SD card | | | journald setting, decide |
| BeamMP | server in `/opt/beamng-server` (binary, config, log), not running, no unit; ufw 30814/udp still open | | | drop |
| Desktop | lightdm running a session; wayvnc installed but off | | | drop: headless |
| snapd | installed, no snaps | | | drop |
| 13 exited containers | screego, crater, 15–17 months old | | | drop |

amanita pulls `/mnt/usbhdd/backups` daily at 03:45 (`pull-pi-backup`), the watchdog checks it at
12:00, and the weekly Proton mirror takes it offsite.

### Exact images running on 2026-11-22

The floating tags (`latest`, `mysql:8`, `redis:alpine`) would quietly upgrade on any re-pull, so these
are pinned by digest:

```
invoiceninja/invoiceninja-debian@sha256:bc39f58b632353ef591eb5411ad1da77229105ffce4347482904349171adca5b
mysql@sha256:32cdfd01c2996419a2ff4ced7234c06af60a63e714e182e3cc5966182b67034c   (MySQL 8.4.5)
redis@sha256:73734b014e53b3067916918b70718ca188c16895511a272a020c9a71084eecda   (invoiceninja's)
nginx@sha256:b2e814d28359e77bd0aa5fed1939620075e4ffa0eb20423cc557b375bd5c14ad
pihole/pihole@sha256:706fa18daedc85b73684b57468b7e20ec213cfaf98be735aadee183825188ea0
ossapps/splitpro:v2.1.6, ossapps/postgres:17.7-trixie, axllent/mailpit:v1.33.1
ghcr.io/paperless-ngx/paperless-ngx:3.3.2, redis:7.4-alpine, ghcr.io/icereed/paperless-gpt:v0.31.0
henrygd/beszel-agent:0.21.0
```

## Target system

- Flake input `nvmd/nixos-raspberrypi` (Pi 5 kernel, firmware, bootloader; active). New host
  `hosts/raspi/`, slim: no desktop and not `modules/core` (desktop-heavy), only users and ssh keys,
  agenix with the Pi's new host key, beszel agent, zerotier, smartd, docker.
- Built on amanita (aarch64 through binfmt emulation, kernel from the project's binary cache), first
  boot from an SD image of that config, later switches with `nh os switch --target-host`.
- Boots from the SD card as today. Static 10.0.0.10, hostname `raspi`, USB disk by UUID with
  `nofail` as today.
- Containers through `virtualisation.oci-containers`, images referenced by digest and loaded from
  the saved tarballs below, so nothing depends on upstream tags still existing.

## Before the switch

1. **Freeze the images:** `docker save` every running image to `/mnt/usbhdd/images/` and copy them to
   amanita. NixOS loads these, so the exact same bits run.
2. **Final backups with the apps stopped:** InvoiceNinja (mysqldump `--single-transaction`, tar of
   `public` and `storage`, `.env`), SplitPro (pg_dump, uploads, `.env`), Paperless (export), Pi-hole
   (teleporter export), ZeroTier identity, a tar of `/etc`. Pull to amanita, compare checksums.
3. **Cold copy:** with everything stopped, rsync all of `/mnt/usbhdd/apps` to amanita
   (`/mnt/backup/raspi-cold-<date>`), so even the raw MySQL files exist twice.
4. **Restore drills on amanita**, from the pulled copies, never touching the Pi:
   - InvoiceNinja: the same image digests on amanita, the dump imported into MySQL 8.4.5, `storage`
     and `public` mounted, the same `.env`. Check by hand and note the numbers here: login works,
     number of clients, number of invoices, the newest invoice number matches the Pi, its PDF
     renders, an uploaded document opens, recurring invoices are listed.
   - SplitPro: pg_dump into postgres 17.7; the balances page matches the Pi.
   - Paperless: `document_importer` into an empty 3.3.2; document count matches, a random document opens.
   - Only when all three pass: switch.

### Drill results

**InvoiceNinja, part 1, the data: passed 2026-11-22.** The 02:00 dump as pulled to amanita
(`db-20261122-020001.sql.gz`, 104 KB), restored into MySQL 8.4.5 by the Pi's digest with no network,
matches the live database line for line (`drills/invoiceninja-db.sh`).

```
clients 2 · invoices 10 (9 not deleted) · payments 9 · recurring 0 · quotes 0 · credits 0
expenses 27 · documents 41 · users 1 · tables 75
newest invoice 0009 · 2026-04-20 · 3480.00 · invoice total 35712.00 = payment total 35712.00
invoices last changed 2026-05-11 12:04:40
CHECKSUM TABLE equal for clients, invoices, payments, paymentables, recurring_invoices, documents
(v5 has no invoice_items table: line items live inside invoices)
```

**InvoiceNinja, part 2, the app: passed 2026-11-22** (`drills/invoiceninja-app.sh up`, then `down`).
The Pi's own compose file, `.env` and nginx config from the weekly config backup, the four images by
digest, last night's dump and files, on amanita. App, MySQL and Redis on an internal network with no
way out (checked: the app could not reach the internet; the `.env` mails to a log file anyway); nginx
alone serves `127.0.0.1:8012`, the `.env`'s APP_URL. Checked: 41 of 41 documents have their file
(629 files restored), no errors in the app log, login works, invoice 0009's PDF renders (snappdf,
offline) and the opened documents show. So the files tarball and `APP_KEY` are good too.

Still to drill: SplitPro and Paperless.

## Switch

The Pi 5 tries the SD card first, then NVMe, then USB (`BOOT_ORDER=0xf461`): it boots the stick only
while the SD card is out. Once both carry the NixOS image they also share its partition labels
(`FIRMWARE`, `NIXOS_SD`, which the system mounts by), so never boot with both plugged in.

1. **Prepare the stick** (no downtime): the image built on amanita
   (`nix build .#nixosConfigurations.raspi.config.system.build.sdImage --option extra-substituters
   https://nixos-raspberrypi.cachix.org`) written onto the stick by its by-id path; the Debian SSH host
   keys and `/var/lib/zerotier-one` copied onto it.
2. **Stage 1, NixOS from the stick:** stop the apps on Debian, run every backup once more, pull to
   amanita. Shut down, take the SD card out (it stays untouched), boot. DNS falls back to Cloudflare
   meanwhile. Check ssh, the USB disk, beszel, zerotier; the images load, the apps come up one by one
   and are checked against the drill numbers; every backup timer run once, amanita's pull and
   watchdog green.
3. **Stage 2, onto the SD card**, once stage 1 runs well: insert the Debian card while NixOS runs
   from the stick; save it whole as an image onto the USB disk (`/mnt/usbhdd/images/debian-sd-<date>.img.zst`),
   write the NixOS image onto it, copy the host keys and zerotier identity in. Reboot without the
   stick: NixOS from the SD card, the same setup as before. The stick stays as a NixOS rescue system.

### Stage 1 done 2026-11-22

NixOS from the stick at 08:56, all apps up at 09:30. Checked: InvoiceNinja's counts, newest invoice,
total and table checksums identical to the drill; Pi-hole answers and blocks; all 18 Gatus checks; all
four backup jobs wrote on NixOS and amanita pulled them, watchdog green; Beszel agent connected;
ZeroTier the same node (`20d3ee29a0`) and address; ssh with the old host key, no warning.

Learned on the way:
- The image's root-partition growing fails on a USB stick (it computes partition "18" for
  `/dev/sdb2`); grown by hand with `sfdisk -N 2` and `resize2fs`. The SD card is the case it is written for.
- Loading the 6.8 GB of saved images took about 25 minutes on the stick, which writes many small files slowly.
- The clock read 20:56 until NTP synced, so the backup timers fired at boot before any app ran (harmless).
- The router's DNS still held Debian's IPv6 lease (`::fc2`), so the watchdog pings over IPv4 now.
- Debian's `cmdline.txt` fix for memory accounting does not carry over: it is `boot.kernelParams` here.

### Stage 2 done 2026-11-22

The Debian card, saved whole onto the USB disk first (`/mnt/usbhdd/images/debian-sd-20261122.img.zst`,
9.7 GB for the 64 GB card, `zstd -t` clean), then written with NixOS by `write-stick.sh`. NixOS from
the SD card at 10:00, all apps up 10:13. Checked again: InvoiceNinja's counts, total and checksums as
in the drill; Pi-hole answers and blocks; Gatus; all four backups on the card, pulled, watchdog green;
memory accounting on (no docker warning, no Beszel errors).

Learned on the way:
- On the SD card the root partition grew by itself (58 GB).
- The Pi has no clock battery: the fresh card booted at the image's build date (2026-03-17), NTP jumped
  the clock mid image-load and docker's lease expired ("lease does not exist"). The image loader now
  waits for the synced time; the backup units wait for their apps when a timer fires during boot.
- Loading the images took 6½ minutes on the card, against 25 on the stick.
- The apps only `want` the image loader: with `requires`, every update touching the loader restarted all of them.

Rollback from here: the Transcend stick boots a working NixOS (with the SD card out), and from there
the Debian image can go back onto the card. The raw app folders and images from before the switch
are also on amanita (`/mnt/backup/raspi-cold-20261122`).

### After: Pi-hole native, AdGuard Home tried and dropped (2026-11-22)

AdGuard Home ran for a morning and answered exactly like Pi-hole, but saw one client, the router: every
lookup comes through the router's dnsmasq, which attaches the asking device's address (`add-subnet`), and
AdGuard only logs that address where Pi-hole counts it as the client. Pi-hole is back, now from the NixOS
module (`pihole.nix`) instead of docker, with its history since 2026-08-28 copied from amanita's cold copy.
Its data is on the USB disk (`apps/pihole`; `ftl.env` holds the login and Glance's app password as hashes,
since the module's pihole.toml is read-only from Nix), and `/var/log` is back there as on Debian, so the SD
card holds only the system.

Learned: the module's `lists` fail on every start after the first (UNIQUE constraint) and it never refreshes
them, so the list lives in Pi-hole's database and `pihole-gravity` refreshes it weekly. A refresh swaps
gravity.db under FTL: without SIGRTMIN afterwards it keeps reading the old file and stops blocking.

Updates from amanita (fish abbreviation `nos-pi`):
`nixos-rebuild switch --flake .#raspi --target-host raspi --sudo --option extra-substituters https://nixos-raspberrypi.cachix.org`

## Rollback

- Before stage 2: power off, stick out, SD card in: Debian starts with everything as before.
- After stage 2: boot from the stick (SD card out) for a working NixOS, or, from there, write the
  saved Debian image back onto the card.

Both work only because the switch changes no versions: the same MySQL and app versions wrote the
data, so either system reads it. Never run an upgraded app against the data while Debian is still a
fallback.

## Afterwards, one at a time

- Pi-hole → AdGuard Home (native module), with its widgets for Glance.
- Paperless → native module (version-matched), then upgrades.
- Proton Mail Bridge (nixpkgs 3.25.0, has a NixOS module) for Paperless' mail fetch.
- cloudflared, for the internet route.
- InvoiceNinja upgrades, each only after a fresh backup and a drill.
- InvoiceNinja login: a stronger password and two-factor login, then `IN_USER_EMAIL` and
  `IN_PASSWORD` out of its `.env` (setup-only values in plain text, also inside the weekly config
  backups).
- Data off the USB disk (it has dropped out before) onto an NVMe on the Pi 5's PCIe slot.

## Open questions

- None for the switch itself. Network zones (a dmz for the Pi, the Dreame offline in iot) are planned
  in `NETWORK.md`; Proton Mail Bridge waits for the dmz, since a logged-in Bridge lets anyone with
  root on the Pi read all mail.
