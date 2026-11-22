# raspi: Debian → NixOS

Status: plan, nothing switched yet. Written 2026-11-22 from an inventory of the running Pi
(Raspberry Pi 5 Model B Rev 1.1, Debian 12, kernel 6.12.34+rpt-rpi-2712, root on a 64 GB SD card,
data on a 1 TB WD USB disk).

## Ground rules

1. **The data does not move.** Everything that matters lives on the USB disk (`/mnt/usbhdd`, ext4,
   UUID `d2c9cf26-b12d-4074-b9b3-4a5d450e34d8`). NixOS goes on a **new SD card**; the current card
   stays untouched in a drawer. Rollback = power off, swap cards back, boot.
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
matches the live database line for line. The script is `drill-invoiceninja-db.sh` (session scratchpad
for now; it belongs next to the backups once the Pi runs NixOS).

```
clients 2 · invoices 10 (9 not deleted) · payments 9 · recurring 0 · quotes 0 · credits 0
expenses 27 · documents 41 · users 1 · tables 75
newest invoice 0009 · 2026-04-20 · 3480.00 · invoice total 35712.00 = payment total 35712.00
invoices last changed 2026-05-11 12:04:40
CHECKSUM TABLE equal for clients, invoices, payments, paymentables, recurring_invoices, documents
(v5 has no invoice_items table: line items live inside invoices)
```

**InvoiceNinja, part 2, the app: still to do.** The same app image on amanita with the restored
`storage` and `public` and the backed-up `.env`, cut off from the internet so it cannot send mail
or run reminders: log in, open the newest invoice's PDF, open a few of the 41 documents. That is
what proves the files tarball and `APP_KEY` work, which the checksums cannot.

## Switch day

1. DNS: the router falls back to Cloudflare while Pi-hole is down, so the network keeps working
   (ads get through for that time).
2. Stop all containers on Debian, run the backups once more, pull to amanita.
3. Power off, put in the new NixOS card, boot. Check ssh, the USB disk, beszel, zerotier.
4. Start the apps one at a time and check each against its drill numbers: InvoiceNinja, SplitPro,
   Paperless, Pi-hole, the rest.
5. Backups as systemd timers; run each once; amanita's pull and watchdog green.
6. Keep the old SD card for at least four weeks.

## Rollback

Power off, swap the old card back in, boot: Debian starts with everything as before. That works only
because the switch changes no versions: the same MySQL and app versions wrote the data, so the old
system reads it. Never run an upgraded app against the data while the old card is still the fallback.

## Afterwards, one at a time

- Pi-hole → AdGuard Home (native module), with its widgets for Glance.
- Paperless → native module (version-matched), then upgrades.
- Proton Mail Bridge (nixpkgs 3.25.0, has a NixOS module) for Paperless' mail fetch.
- cloudflared, for the internet route.
- InvoiceNinja upgrades, each only after a fresh backup and a drill.
- Data off the USB disk (it has dropped out before) onto an NVMe on the Pi 5's PCIe slot.

## Open questions

- Network zones before anything faces the internet: does the Pi get its own segment (a DMZ next to
  `lan` and the Wi-Fi-only `iot` network on the router)? Proton Mail Bridge waits for that answer,
  since a logged-in Bridge lets anyone with root on the Pi read all mail.
