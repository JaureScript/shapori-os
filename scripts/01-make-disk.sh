#!/usr/bin/env bash
# Shapori OS - Paso 1: crea la imagen de disco GPT/UEFI con 3 particiones.
# NO necesita root ni dispositivos loop (sirve en el Linux de ChromeOS, Codespaces, Debian/Ubuntu).
#   p1 BOOT   (ESP, FAT32, 512 MiB) -> /boot/efi
#   p2 SYSTEM (ext4, 8 GiB)         -> /
#   p3 DATA   (ext4, resto)         -> /data
# Uso: ./scripts/01-make-disk.sh [imagen] [tamaño]
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PATH:/usr/sbin:/sbin"   # sgdisk, mkfs.fat, mke2fs y blkid viven en sbin

IMG="${1:-shapori.img}"
SIZE="${2:-16G}"

for cmd in sgdisk mkfs.fat mke2fs blkid truncate dd awk; do
  command -v "$cmd" >/dev/null || {
    echo "Falta '$cmd'. Instala: sudo apt install gdisk dosfstools e2fsprogs util-linux" >&2; exit 1; }
done
[ ! -e "$IMG" ] || { echo "$IMG ya existe. Bórralo (rm $IMG) o usa otro nombre." >&2; exit 1; }

# Devuelve "sector_inicial tamaño_en_KiB" de la partición $1 (sectores de 512 bytes)
part_geometry() {
  local info first last
  info="$(sgdisk -i "$1" "$IMG")"
  first="$(echo "$info" | awk '/^First sector:/ {print $3}')"
  last="$(echo "$info"  | awk '/^Last sector:/  {print $3}')"
  echo "$first $(( (last - first + 1) / 2 ))"
}

echo "[1/5] Creando imagen $IMG ($SIZE, archivo sparse)"
truncate -s "$SIZE" "$IMG"

echo "[2/5] Creando tabla GPT y particiones"
sgdisk --zap-all "$IMG" >/dev/null 2>&1 || true
sgdisk -n1:0:+512M -t1:EF00 -c1:BOOT   "$IMG" >/dev/null
sgdisk -n2:0:+8G   -t2:8300 -c2:SYSTEM "$IMG" >/dev/null
sgdisk -n3:0:0     -t3:8300 -c3:DATA   "$IMG" >/dev/null
sgdisk -p "$IMG"

echo "[3/5] Formateando BOOT (FAT32): se formatea un archivo temporal y se copia al offset de la partición"
read -r S1 K1 < <(part_geometry 1)
ESP_TMP="$IMG.esp.tmp"
trap 'rm -f "$ESP_TMP"' EXIT
truncate -s "${K1}K" "$ESP_TMP"
mkfs.fat -F 32 -n BOOT "$ESP_TMP" >/dev/null
dd if="$ESP_TMP" of="$IMG" bs=512 seek="$S1" conv=notrunc,sparse status=none

echo "[4/5] Formateando SYSTEM y DATA (ext4) directamente dentro de la imagen"
format_ext4() {   # $1 = número de partición, $2 = etiqueta
  local s k
  read -r s k < <(part_geometry "$1")
  mke2fs -q -F -t ext4 -L "$2" -E "offset=$((s * 512)),lazy_itable_init=1,lazy_journal_init=1" "$IMG" "${k}k"
}
format_ext4 2 SYSTEM
format_ext4 3 DATA

echo "[5/5] Verificación"
sgdisk -v "$IMG" || true
for n in 1 2 3; do
  read -r s k < <(part_geometry "$n")
  printf 'Partición %s (inicio sector %s, %s KiB): ' "$n" "$s" "$k"
  { blkid -p -O "$((s * 512))" -o export "$IMG" | grep -E '^(LABEL|TYPE)=' | tr '\n' ' '; } || true
  echo
done
echo
ls -lsh "$IMG"
echo "Listo: $IMG (tamaño aparente = SIZE; el primer número es lo que ocupa realmente en disco)"
