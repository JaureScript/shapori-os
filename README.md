# Shapori OS

Sistema operativo de propósito específico (Linux minimalista + contenedor Android con Waydroid) para digitalizar el triaje clínico **100 % offline** en ambulatorios rurales del Estado Aragua, sobre hardware de bajos recursos (laptops Canaima).

El nombre *shapori* proviene del pueblo yanomami (Amazonas, Venezuela) y designa al chamán-curandero. Ver `docs/origen-del-nombre.md`.

| | |
|---|---|
| Institución | UNEFA, Núcleo Aragua - Maracay |
| Asignatura | Sistemas Operativos |
| Profesora | Yanmar Rodriguez |
| Integrantes | Juan Jaure, Juliet Marquez, Diego Narvaez |
| Vía técnica | **Opción B**: Linux base (Debian) + contenedor Android (Waydroid) |

## Estado del proyecto

| Semana | Entregable | Estado |
|---|---|---|
| 4 | Repositorio activo | En curso |
| 4 | Particiones UEFI (boot/system/data) | En curso |
| 6 | Hito 1 teórico: informe de arquitectura del kernel y flujo de arranque | Pendiente |
| 8 | Hito 1 práctico: kernel x86 booteable con Binder (y ashmem/memfd) | Pendiente |
| 11 | Hito 2 teórico: modelado de zRAM, Binder y gráficos | Pendiente |
| 12 | Hito 2 práctico: compositor Wayland + primera carga visual de Android | Pendiente |
| 13-15 | Periféricos, cgroups v2, lmkd, prueba de estrés | Pendiente |
| 16 | Memoria IEEE, sustentación, scripts y demo | Pendiente |

## Estructura del repositorio

~~~
docs/       documentación, decisiones, bitácora y evidencias
scripts/    scripts de construcción reproducibles
kernel/     configuración y parches del kernel (Semanas 5-8)
bridge/     demonio en C (puente IPC host <-> contenedor)
config/     zRAM, cgroups v2, Waydroid, compositor
~~~

## Reproducir la Semana 4 (particiones UEFI)

El script **no necesita root ni dispositivos loop**: trabaja sobre un archivo imagen. Funciona en cualquier Debian/Ubuntu, incluido el Linux de ChromeOS (Crostini) y GitHub Codespaces.

~~~
sudo apt install gdisk dosfstools e2fsprogs util-linux
./scripts/01-make-disk.sh 2>&1 | tee docs/evidencias/01-make-disk.log
~~~

Resultado: `shapori.img` con tabla GPT y tres particiones (BOOT FAT32 / SYSTEM ext4 / DATA ext4). Detalles en `docs/particiones.md`.

`scripts/02-base-system.sh` (instala Debian mínimo + GRUB UEFI y permite arrancar en QEMU) requiere root y dispositivos loop: se ejecuta en una máquina Linux real, a partir de la Semana 5.
