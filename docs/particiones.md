# Particiones UEFI (Semana 4)

## Diseño (tabla GPT)

| # | Etiqueta | Tipo GPT | Tamaño | Sistema de archivos | Montaje previsto | Rol |
|---|---|---|---|---|---|---|
| 1 | BOOT | EF00 (ESP) | 512 MiB | FAT32 | /boot/efi | Cargador UEFI (GRUB) |
| 2 | SYSTEM | 8300 | 8 GiB | ext4 | / | Debian base, kernel, Waydroid |
| 3 | DATA | 8300 | resto (~7,5 GiB) | ext4 | /data | Base de datos de pacientes, datos de Waydroid, logs |

## Justificación del diseño
- GPT + ESP en FAT32 es lo que exige el arranque UEFI.
- DATA separada: permite reinstalar o actualizar SYSTEM sin perder datos clínicos, y aplicar políticas distintas (journal, cifrado, copias de seguridad).
- No se crea partición swap: la memoria se comprimirá con zRAM (Fase 2).
- Se trabaja sobre un archivo imagen (`shapori.img`) para no arriesgar el disco del equipo. El mismo esquema se podrá escribir después en un USB o disco físico con `dd`.

## Cómo se construyó (sin root ni dispositivos loop)

~~~
./scripts/01-make-disk.sh 2>&1 | tee docs/evidencias/01-make-disk.log
~~~

| Herramienta | Para qué se usó |
|---|---|
| `truncate` | Crear el archivo imagen (sparse: ocupa solo lo escrito) |
| `sgdisk` | Crear la tabla GPT y las 3 particiones; `sgdisk -i N` para leer inicio y tamaño |
| `mkfs.fat` + `dd` | Formatear BOOT como FAT32 en un archivo temporal y escribirlo en el offset de la partición |
| `mke2fs -E offset=` | Formatear SYSTEM y DATA como ext4 directamente dentro de la imagen, en el offset de cada partición |
| `blkid -p -O` | Verificar etiqueta y tipo de sistema de archivos de cada partición |

Esta técnica evita montar dispositivos loop, que requieren privilegios no disponibles en el Linux de ChromeOS. El arranque real (GRUB + kernel en QEMU/OVMF) se prueba a partir de la Semana 5 con `scripts/02-base-system.sh` en una máquina Linux con root.

## Evidencias
- `evidencias/01-make-disk.log`: tabla GPT (`sgdisk -p`), verificación (`sgdisk -v`) y tipo/etiqueta de cada partición (`blkid`).

