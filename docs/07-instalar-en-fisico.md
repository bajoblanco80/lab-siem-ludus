# 07 · Instalar el servidor en un equipo físico

Tutorial para preparar el equipo donde correrá Ludus. Hay dos caminos; **este
repositorio recomienda el A (Debian 13)**.

> Los pasos se basan en la documentación oficial de
> [Ludus](https://docs.ludus.cloud/docs/quick-start/install-ludus),
> [Debian](https://www.debian.org/distrib/netinst) y
> [Proxmox VE](https://pve.proxmox.com/wiki/Installation), pero **este tutorial no
> se ha ejecutado aún en un equipo real** (ver [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md), sección H).
> Instalar un sistema operativo **borra el disco elegido**: haz copia de lo que te importe.

## 1. Elegir camino

| | **A · Debian 13 en físico** (recomendado) | **B · Proxmox VE 9 en físico** |
| --- | --- | --- |
| Qué es | Instalas Debian y el instalador de Ludus añade Proxmox encima | Instalas Proxmox con su instalador y Ludus se instala sobre él |
| Lo que dice Ludus | «Si partes de cero, la instalación de Debian 12/13 en físico es la recomendada» | Soportado, pero avisa de que *«una instalación de Proxmox existente puede dar problemas con personalizaciones»* |
| Reinicio | El instalador de Ludus **reinicia** el equipo y sigue solo | Ludus se instala **sin reiniciar** |
| Ventajas | Camino más probado y limpio, sin configuración previa que choque | Instalador de Proxmox con opciones de disco (ZFS, RAID por software); interfaz web desde el primer minuto |
| Inconvenientes | Ninguno relevante para este laboratorio | Si tocas la red o el almacenamiento antes, puedes chocar con lo que cree Ludus |
| Elige esto si… | Montas el equipo desde cero (lo habitual) | Ya tienes un Proxmox 8/9 en marcha o quieres ZFS con varios discos |

**Al final de ambos caminos tendrás Proxmox** (interfaz web en el puerto 8006) con
Ludus encima. La diferencia es solo por dónde empiezas.

### Mi recomendación
**Camino A.** Es el que recomienda el propio Ludus para equipos nuevos, el que menos
sorpresas da y el que cubren estas guías. Usa **Debian 13** (la estable actual,
13.x «trixie»; Ludus soporta también la 12).

## 2. Hardware

| Recurso | Mínimo | Recomendado para este laboratorio |
| --- | --- | --- |
| CPU | x86_64 con virtualización, Passmark > 6000 | 6–8 núcleos o más |
| RAM | 32 GB por rango desplegado (recomendación de Ludus) | 64–128 GB si es para una clase |
| Disco | 200 GB para plantillas + 50 GB por rango | NVMe de 500 GB–1 TB |
| Red | Cable (Ludus no admite WiFi) | 1 GbE, una sola tarjeta (sin *bonding*) |

Sirve un mini PC potente, una estación de trabajo o un servidor usado. Para 16 GB
mira el [perfil lite](06-perfil-lite.md). **No sirve** un Mac con Apple Silicon
(Proxmox y las plantillas son x86).

## 3. Preparar el equipo (BIOS/UEFI)

1. Entra en la configuración del firmware (suele ser `Supr`, `F2` o `F10` al arrancar).
2. **Activa la virtualización:** *Intel VT-x* / *Virtualization Technology* (Intel) o
   *SVM Mode* (AMD). Es imprescindible.
3. Activa el arranque desde USB y, si el equipo lo pide, desactiva *Secure Boot* para el instalador.
4. Conecta el **cable de red** al router.

Cuando tengas un sistema Linux funcionando, comprueba la virtualización:
```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo      # debe dar un número mayor que 0
```

## 4. Crear el USB de instalación

Descarga la ISO (en otro equipo):
- **Debian 13:** `debian-13.x.x-amd64-netinst.iso` desde
  [debian.org/distrib/netinst](https://www.debian.org/distrib/netinst).
- **Proxmox VE 9:** desde [proxmox.com/downloads](https://www.proxmox.com/en/downloads).

Comprueba la integridad (en Debian, descarga `SHA256SUMS` de la misma carpeta que la ISO):
```bash
sha256sum -c --ignore-missing SHA256SUMS
```

Graba el USB. **Esto borra el USB y, si te equivocas de dispositivo, el disco equivocado.**

| Tu equipo | Cómo |
| --- | --- |
| **Linux** | `lsblk` (mira el nombre antes y después de insertar el USB), desmonta y: `sudo dd if=./ARCHIVO.iso of=/dev/sdX bs=4M conv=fsync status=progress` |
| **Windows** | [balenaEtcher](https://etcher.io), o Rufus eligiendo **modo DD** si ofrece descargar otro GRUB (responde *No*) |
| **macOS** | `hdiutil convert ARCHIVO.iso -format UDRW -o ARCHIVO.dmg`, `diskutil list`, `diskutil unmountDisk /dev/diskN` y `sudo dd if=ARCHIVO.dmg bs=1m of=/dev/rdiskN` (o Etcher) |

## 5A. Camino A · Instalar Debian 13

Arranca el equipo desde el USB y elige **Install** (instalación en modo texto).

| Pantalla | Qué elegir |
| --- | --- |
| Idioma, país, teclado | Español / España / Español |
| Red | Autodetección por cable; si falla, mira la nota de *firmware* abajo |
| Nombre de equipo | `ludus` (o el que quieras) |
| Dominio | Déjalo vacío |
| Clave de root | Una clave larga. **Anótala** en un gestor de contraseñas |
| Usuario normal | Créalo (lo necesitas para entrar por SSH) |
| Particionado | *Guiado: usar todo el disco* (el disco elegido se borra). Con un solo NVMe, *todo en una partición* |
| Selección de software | **Quita** «Entorno de escritorio» y «Servidor de impresión». **Marca** «Servidor SSH» y «Utilidades estándar del sistema» |
| GRUB | Instalar en el disco principal |

Al terminar, retira el USB y reinicia. Entra por SSH desde otro equipo:
```bash
ssh tu-usuario@IP-del-servidor
su -                                    # pasa a root
apt update && apt full-upgrade -y
reboot
```
> **Firmware.** Si el instalador no detecta tu tarjeta de red, consulta la
> [guía de firmware de Debian](https://wiki.debian.org/Firmware); las imágenes
> oficiales recientes (desde Debian 12) ya incluyen el firmware no libre más habitual.

Ahora instala Ludus como **root**, como indica la guía oficial:
```bash
apt update && apt install curl sudo ca-certificates
curl --proto '=https' --tlsv1.2 -sSf https://ludus.cloud/install | bash
```
El instalador te pregunta valores (los de por defecto suelen servir) y **reinicia el
equipo**. Después continúa solo: sigue el avance con `ludus-install-status` (como root,
por SSH). **Cuando termine**, sigue con [docs/01-guia-docente.md](01-guia-docente.md),
sección 3 (construir plantillas).

## 5B. Camino B · Instalar Proxmox VE 9 y luego Ludus

1. Arranca desde el USB de Proxmox y elige **Install Proxmox VE (Graphical)**.
2. **Disco de destino:** *ext4* (por defecto, usa LVM) es lo más simple con un solo
   disco. *ZFS* solo si tienes varios discos **sin** RAID por hardware.
   Se borra el disco elegido.
3. **Red:** pon una **IP fija** fuera del rango DHCP del router (o reserva esa IP en el
   router), con su puerta de enlace y DNS. Solo admite IPv4 **o** IPv6 en el instalador.
4. Fija la clave de root y un correo de administración.
5. Reinicia y abre `https://IP-del-servidor:8006` (acepta el certificado). Usuario `root`, dominio *PAM*.
6. Configura los repositorios de actualizaciones: sin suscripción hay que usar los
   repositorios públicos (consulta la documentación de Proxmox) y actualiza el sistema.
7. **No cambies nada más** (ni redes ni almacenamiento) antes de instalar Ludus: la guía
   oficial lo desaconseja. Instala Ludus con el mismo comando del camino A y, durante el
   instalador, **elige con cuidado los almacenamientos** (*datastores*) que te pregunte.

Si más tarde cambias de almacenamiento, hay que dar permisos a los grupos de Ludus
(ver [Ludus sobre Proxmox](https://docs.ludus.cloud/docs/deployment-options/proxmox)).

## 6. Comprobar que quedó bien

```bash
ludus-install-status          # como root: debe indicar que terminó
systemctl status ludus ludus-admin
```
Abre `https://IP-del-servidor:8006` (Proxmox) para ver el panel. Luego crea usuarios y
construye las plantillas siguiendo la [guía del docente](01-guia-docente.md).

## 7. Red y acceso: lo que conviene saber

- **Fija la IP** del servidor (IP estática o reserva DHCP): si cambia, perderás el acceso.
- **No expongas a Internet** el panel de Proxmox ni los puertos de administración de Ludus.
- Para que los alumnos entren **desde fuera del centro** con su VPN WireGuard, Ludus
  necesita una IP pública y poder abrir el puerto de WireGuard hacia el servidor
  (redirección de puertos o cortafuegos). Dentro de la misma red local no hace falta.
- Entra por SSH **con clave** y no dejes la clave de root por defecto.
- Un servidor de clase es crítico: pon un **SAI** si puedes y haz copia de seguridad de
  la configuración de Ludus (`/opt/ludus/config.yml`).

## 8. Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| El instalador de Ludus dice que no hay virtualización | VT-x/SVM desactivado en la BIOS | Actívalo (apartado 3) |
| No arranca desde el USB | Orden de arranque o Secure Boot | Elige el USB en el menú de arranque; prueba sin Secure Boot |
| Sin red en el instalador | Falta de firmware o cable | Cambia de puerto/cable; revisa la guía de firmware |
| Tras instalar Ludus no puedo entrar por SSH | La IP cambió con el reinicio | Mira la nueva IP en el router; reserva esa IP |
| `ludus-install-status` no avanza | Falta de Internet o disco | Comprueba la red (por cable) y el espacio en disco |
