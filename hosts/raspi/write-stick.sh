#!/usr/bin/env bash
# Runs ON the Pi (ssh raspi "bash -s" < this; arguments: image path, target by-id path). Writes the NixOS
# image onto a removable USB stick or an SD card, then copies this Pi's SSH host keys and ZeroTier
# identity onto the new system, so the first boot keeps `ssh raspi` trusted and the same ZeroTier node.
# Refuses any target that is the disk holding /mnt/usbhdd or the disk / boots from, or bigger than 128 GB.
# Prints device facts and file names, never key contents.
set -euo pipefail
img=$1
target=$2
die() { echo "REFUSED: $*" >&2; exit 1; }

dev=$(readlink -f "$target")
name=$(basename "$dev")
data=$(lsblk -no PKNAME "$(findmnt -no SOURCE /mnt/usbhdd)")
boot=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
[ -b "$dev" ] || die "$target is not a block device"
[ "$name" != "$data" ] || die "$dev holds /mnt/usbhdd"
[ "$name" != "$boot" ] || die "$dev is what / runs from"
size=$(lsblk -bdno SIZE "$dev")
[ "$size" -lt 128000000000 ] || die "$dev is $size bytes, too big for a boot medium"
echo "target: $dev ($(lsblk -dno MODEL "$dev" | xargs), $((size / 1000000000)) GB); data disk $data and boot disk $boot left alone"

unmount_all() {
  for p in $(lsblk -lnpo NAME "$dev" | tail -n +2); do
    if findmnt -n "$p" >/dev/null; then sudo umount "$p"; fi
  done
}
unmount_all
echo "writing $(basename "$img") ..."
zstd -dc "$img" | sudo dd of="$dev" bs=4M conv=fsync status=none
sync
sudo partprobe "$dev"
sleep 3
unmount_all # a desktop may have auto-mounted the fresh partitions

root=$(lsblk -lnpo NAME,LABEL "$dev" | awk '$2 == "NIXOS_SD" {print $1}')
[ -n "$root" ] || die "no NIXOS_SD partition on $dev after writing"
mnt=$(mktemp -d)
sudo mount "$root" "$mnt"
trap 'sudo umount "$mnt"; rmdir "$mnt"' EXIT
[ -d "$mnt/nix/store" ] || die "$root has no /nix/store"

sudo install -d -m 755 "$mnt/etc/ssh" "$mnt/var/lib"
sudo cp -a /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub \
  /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub "$mnt/etc/ssh/"
sudo cp -a /var/lib/zerotier-one "$mnt/var/lib/"
# not Debian's pid and port files, nor its links to /usr/sbin binaries
z="$mnt/var/lib/zerotier-one"
sudo rm -f "$z/zerotier-one.pid" "$z/zerotier-one.port"
for l in zerotier-cli zerotier-idtool zerotier-one; do
  if [ -L "$z/$l" ]; then sudo rm "$z/$l"; fi
done
echo "copied: $(sudo ls "$mnt/etc/ssh" | tr '\n' ' ')"
echo "copied: zerotier-one with $(sudo ls "$mnt/var/lib/zerotier-one" | tr '\n' ' ')"
echo "zerotier node on the new system: $(sudo cut -c1-10 "$mnt/var/lib/zerotier-one/identity.public")"
echo "ssh host key fingerprint, new system vs this one:"
ssh-keygen -lf "$mnt/etc/ssh/ssh_host_ed25519_key.pub" | cut -d' ' -f2
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | cut -d' ' -f2
