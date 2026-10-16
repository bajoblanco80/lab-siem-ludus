# 02 · Guía autoalojada: lo monto en mi propio equipo

Para quien no tiene un servidor del centro. Instalas Ludus en **tu** máquina y
eres a la vez administrador y alumno.

## ¿Puedo hacerlo?

| Necesitas | Mínimo |
| --- | --- |
| Un equipo dedicado (no tu portátil de uso diario) | x86_64 con virtualización |
| RAM | **32 GB** para un único rango (el básico usa ~20 GB; el avanzado ~24 GB) |
| Disco | 200 GB, mejor NVMe |
| Red | Por cable. Ludus no admite WiFi |
| Sistema | Debian 12/13 limpio, o Proxmox 8/9 |

Si tienes **16 GB** en un equipo dedicado, mira el
[perfil lite](06-perfil-lite.md) (solo itinerario básico y fuera de lo soportado
por Ludus). Si no cumples ni eso, pide acceso al servidor del centro. Un Mac con
chip Apple Silicon no sirve: Proxmox y las plantillas de este laboratorio son x86.

> **Importante.** La instalación convierte el equipo en un servidor Proxmox. No
> lo hagas en una máquina con datos que quieras conservar sin hacer copia antes.

## Pasos

1. **Instala Debian 12/13** (instalación mínima + SSH) y entra como `root`.
2. **Instala Ludus** (guía oficial):
   ```bash
   apt update && apt install curl sudo ca-certificates
   curl --proto '=https' --tlsv1.2 -sSf https://ludus.cloud/install | bash
   ```
   El equipo se reinicia y la instalación continúa sola. Mira `ludus-install-status`.
3. **Crea tu usuario y configura el CLI.** Sigue
   [Use the CLI locally](https://docs.ludus.cloud/docs/quick-start/using-cli-locally)
   y [Create a user](https://docs.ludus.cloud/docs/quick-start/create-a-user):
   ```bash
   ludus user add --name "Tu Nombre" --userid TN --email tu@correo.es
   export LUDUS_API_KEY="<la clave que muestra el comando>"
   ```
4. **Construye las plantillas** (tarda horas, déjalo trabajando):
   ```bash
   ludus templates build
   ludus templates logs -f
   ```
5. **Clona este repositorio y despliega:**
   ```bash
   git clone https://github.com/bajoblanco80/lab-siem-ludus.git && cd lab-siem-ludus
   scripts/instalar-roles.sh
   scripts/preparar-config.sh basico        # o avanzado
   ludus range config set -f rango/range-config-basico.local.yml
   ludus range deploy
   ludus range logs -f
   ```
6. **Conéctate a tu rango por VPN:**
   ```bash
   ludus user wireguard | tee ludus.conf
   sudo wg-quick up ./ludus.conf
   ```
   Con la VPN activa llegas a las VMs: SSH al 22 de las Linux, RDP al 3389 de
   las Windows (`ludus range rdp` descarga los archivos RDP) y, en la Kali,
   KasmVNC en `https://<IP-de-kali>:8444/`.

Continúa con el itinerario [básico](../itinerario-basico/practica.md) o el
[avanzado](../itinerario-avanzado/practica.md).

## Qué hacer si algo falla
Consulta [04-solucion-problemas.md](04-solucion-problemas.md).
