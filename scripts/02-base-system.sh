#!/usr/bin/env bash
# Shapori OS - Paso 2 (Semana 5+): instala una base Debian mínima en la imagen y deja el arranque UEFI listo.
# REQUIERE root, dispositivos loop e internet: ejecutar en una máquina Linux real, NO en el Linux de ChromeOS.
# Uso: sudo ./scripts/02-base-system.sh [imagen]
# Variables opcionales: SUITE=bookworm  MIRROR=http://deb.debian.org/debian
set -euo pipefail
cd "$(dirname "$0")/.."

IMG="${1:-shapori.img}"
SUITE="${SUITE:-trixie}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
MNT=/mnt/shapori

[ "$(id -u)" -eq 0 ] || { echo "Ejecuta con sudo: sudo $0" >&2; exit 1; }
[ -f "$IMG" ] || { echo "No existe $IMG. Ejecuta primero ./scripts/01-make-disk.sh" >&2; exit 1; }
command -v debootstrap >/dev/null || { echo "Falta debootstrap: sudo apt install debootstrap" >&2; exit 1; }

LOOP="$(losetup --find --show --partscan "$IMG")"
cleanup() {
  set +e
  umount -R "$MNT" 2>/dev/null
  losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT
udevadm settle
for _ in 1 2 3 4 5; do [ -b "${LOOP}p3" ] && break; sleep 1; done

echo "[1/5] Montando particiones (SYSTEM -> /, BOOT -> /boot/efi, DATA -> /data)"
mkdir -p "$MNT"
mount "${LOOP}p2" "$MNT"
mkdir -p "$MNT/boot/efi" "$MNT/data"
mount "${LOOP}p1" "$MNT/boot/efi"
mount "${LOOP}p3" "$MNT/data"

echo "[2/5] debootstrap ($SUITE, minbase). Requiere internet; puede tardar varios minutos"
debootstrap --arch=amd64 --variant=minbase "$SUITE" "$MNT" "$MIRROR"

echo "[3/5] Configurando fstab y hostname"
cat > "$MNT/etc/fstab" <<'EOF'
LABEL=SYSTEM  /          ext4  errors=remount-ro  0 1
LABEL=BOOT    /boot/efi  vfat  umask=0077         0 2
LABEL=DATA    /data      ext4  defaults,noatime   0 2
EOF
echo shapori > "$MNT/etc/hostname"

for d in dev dev/pts proc sys run; do mount --bind "/$d" "$MNT/$d"; done

echo "[4/5] Instalando kernel, init y GRUB UEFI dentro de la imagen (chroot)"
chroot "$MNT" /bin/bash -e <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y linux-image-amd64 systemd-sysv grub-efi-amd64 initramfs-tools
[ -f /etc/default/grub ] && sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --no-nvram
update-grub
echo "root:shapori" | chpasswd
CHROOT

echo "[5/5] Verificando"
if [ -f "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]; then
  echo "OK: cargador UEFI instalado (EFI/BOOT/BOOTX64.EFI)"
else
  echo "ERROR: no se encontró BOOTX64.EFI" >&2; exit 1
fi
ls "$MNT"/boot/vmlinuz-* "$MNT"/boot/initrd.img-*
chown "${SUDO_USER:-root}" "$IMG"
echo
echo "Listo. Usuario: root  Contraseña temporal: shapori (cámbiala más adelante)"
echo "Prueba: qemu-system-x86_64 -machine accel=kvm:tcg -m 1024 -bios /usr/share/ovmf/OVMF.fd -drive file=$IMG,format=raw"
