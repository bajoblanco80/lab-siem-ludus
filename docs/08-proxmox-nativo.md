# 08 · Itinerario «servicios» en Proxmox VE sin Ludus

Este itinerario no usa Ludus: se despliega **solo con la API de Proxmox VE 9** y Ansible, desde
tu equipo, sin entrar por SSH al host. Reproduce la red del PDF «Configuración de servicios con
Webmin» y añade un SIEM. La práctica del alumno está en
[itinerario-servicios/practica.md](../itinerario-servicios/practica.md).

Diagramas: [arquitectura y flujo de auditoría](diagramas/arquitectura-servicios.html) ·
[mapa de red](diagramas/mapa-red-servicios.html).

## Qué crea en tu Proxmox

| Objeto | Detalle |
| --- | --- |
| Zona SDN `labsrv` (simple, solo en el nodo elegido) | VNets `soc` 10.20.20.0/24 (gateway .1, SNAT), `nat` 22.44.77.0/24 (gateway .2, SNAT) y `testlab` sin subred (aislada) |
| Imagen `debian-12-genericcloud-amd64.qcow2` en `local:import` | Descargada por la API y verificada con su SHA512 oficial |
| Plantilla 9020 `debian12-cloud` | Disco importado, unidad cloud-init |
| VM 3010 `siem` | 8 GB, 4 vCPU, 40 GB · Wazuh todo en uno |
| VM 3011 `srv` | 2 GB, 2 vCPU · `eth0` en `nat` (22.44.77.250), `eth1` en `testlab` (10.20.30.250) |
| VM 3012 `ns2` · 3013 `cliente` | 1 GB, 1 vCPU · `testlab` (10.20.30.249 y 10.20.30.5) |

Todo lleva la etiqueta `lab-servicios`. Los VMID, el nodo, el almacenamiento y las redes están en
[`proxmox/group_vars/all.yml`](../proxmox/group_vars/all.yml).

## Requisitos

- **Proxmox VE 9.x.** En un clúster, todas las VM van al mismo nodo (la zona simple es local a
  cada nodo). Ese nodo necesita unos 13 GB de RAM libres.
- Almacenamiento `local-lvm` (o el que indiques) para los discos, y uno de tipo directorio con el
  contenido **`import`** activado (*Datacenter → Storage → local → Content*).
- El SDN viene instalado desde PVE 8.1. No hace falta `dnsmasq`: las IP son fijas (cloud-init).
- Un equipo de control Linux con Python 3 y una clave SSH `~/.ssh/id_ed25519.pub`.

## 1. Token de la API

*Datacenter → Permissions → API Tokens → Add*. Después, en *Permissions → Add → API Token
Permission*, dale un rol en la ruta `/`. Este despliegue se ha probado con **`Administrator`**
(el token sigue siendo revocable y no es la contraseña de root). Al terminar puedes revocarlo o
bajarle el rol.

Guarda las credenciales en tu equipo, **no en el repositorio**:
```bash
cat > ~/.proxmox-credentials <<'EOF'
PROXMOX_HOST=https://<ip-de-tu-proxmox>:8006
PROXMOX_TOKEN_ID=<usuario>@<realm>!<token>
PROXMOX_TOKEN_SECRET=<secreto>
EOF
chmod 600 ~/.proxmox-credentials
```
Son los mismos nombres que usa la skill `proxmox-ops`. Los playbooks hablan con Proxmox por
HTTPS sin verificar el certificado (Proxmox usa uno autofirmado).

## 2. Ansible en tu equipo

```bash
python3 -m venv ~/.venvs/lab-ansible && ~/.venvs/lab-ansible/bin/pip install ansible-core
# Si falta ensurepip (Ubuntu sin python3-venv) y tienes uv:
#   uv venv ~/.venvs/lab-ansible && uv pip install --python ~/.venvs/lab-ansible/bin/python ansible-core
export PATH=~/.venvs/lab-ansible/bin:$PATH
```
Solo hace falta `ansible-core`: los playbooks usan módulos `ansible.builtin` y ninguna colección.

## 3. Rutas hacia el laboratorio

Tu equipo llega a las redes del laboratorio a través del nodo. Con su IP en la LAN
(`pve_nodo_ip`, por ejemplo 192.168.1.103):
```bash
sudo ip route add 22.44.77.0/24 via 192.168.1.103
sudo ip route add 10.20.20.0/24 via 192.168.1.103
```
En un escritorio con NetworkManager puedes hacerlo sin `sudo` (hasta el próximo reinicio):
`nmcli device modify <interfaz> +ipv4.routes "22.44.77.0/24 192.168.1.103, 10.20.20.0/24 192.168.1.103"`.
Para toda una clase, añade esas dos rutas estáticas en el router de la LAN.

`testlab` (10.20.30.0/24) **no** se enruta: se llega a `ns2` y `cliente` saltando por `srv`
(`ssh -J labadmin@22.44.77.250 ...`). El playbook comprueba las rutas antes de crear nada y, si
faltan, te dice qué ejecutar.

## 4. Desplegar

Revisa `proxmox/group_vars/all.yml` (`pve_nodo`, `pve_nodo_ip`, almacenamiento) y, desde
`proxmox/`:
```bash
set -a; . ~/.proxmox-credentials; set +a
ansible-playbook desplegar.yml
```
Tarda unos **20 minutos** la primera vez (medido; 7 de ellos el asistente de Wazuh) y unos 40 s
las siguientes. Repetirlo no vuelve a clonar ni a configurar lo que ya existe, y completa un
despliegue que dejó una VM clonada sin configurar (probado). Otros cortes a medias, como una
plantilla sin convertir, están en [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md), sección I.

> **Con el laboratorio en uso, piénsatelo antes de repetir.** Cada ejecución enciende y apaga el
> router temporal: **deshace en caliente el router del alumno** (quita la ruta por defecto de
> `ns2` y `cliente` y deja `ip_forward=0` en `srv`). Lo recupera reiniciando esas tres VM (si el
> alumno lo hizo persistente) o repitiendo sus comandos. **No lo repitas con el modo de pruebas
> activo**: sin Internet, falla al instalar paquetes a mitad de camino.

Antes de tocar nada, el playbook comprueba: versión 9.x, RAM libre del nodo, almacenamientos,
que los VMID estén libres o sean del laboratorio, que no haya cambios SDN ajenos pendientes
(aplicar el SDN aplicaría también esos; si sabes lo que haces, `-e aplicar_sdn_pendiente=si`) y
las rutas de tu equipo.

Al final muestra dónde entrar:

| Qué | Dónde | Credenciales |
| --- | --- | --- |
| Wazuh | `https://10.20.20.10` | `admin`; todas en `siem:/root/wazuh-passwords.txt` |
| Webmin de `srv` | `https://22.44.77.250:10000` | `root`; clave en `proxmox/secretos/webmin.txt` (la misma en `ns2` y `cliente`) |
| SSH | `ssh labadmin@22.44.77.250` | tu clave SSH |

**Alumnos.** Para que entren por SSH con su clave, pon varias claves públicas (una por línea) en
un fichero y apúntalo con `-e lab_ssh_clave_publica_fichero=<fichero>` antes del primer
despliegue. Las claves de Webmin y Wazuh se las das tú.

### Estado inicial (a propósito)
- `srv` **no** reenvía tráfico: durante el despliegue hace de router temporal para instalar
  paquetes en `testlab` y después se quita (`router-temporal.yml`). Configurar el router es la
  primera tarea del alumno.
- Por eso los agentes de `ns2` y `cliente` aparecen **pendientes** (`pending`) hasta que el
  alumno configura el router; con router pasan a `active` en unos 20 s (medido).
  `scripts/verificar-laboratorio.sh --itinerario servicios` los marcará como FALLO hasta entonces.
- Webmin está instalado en las tres máquinas; los servicios del PDF, no.

## 5. Modo de pruebas

Antes de las pruebas ofensivas de la Parte 6 de la práctica
([uso responsable](05-uso-responsable.md), regla 2):
```bash
ansible-playbook modo-pruebas.yml -e estado=activar      # srv y siem sin ruta por defecto
ansible-playbook modo-pruebas.yml -e estado=desactivar   # la devuelve
```
Quita la ruta por defecto de `srv` (el único camino de `testlab` hacia fuera) y de `siem`,
dejando rutas explícitas al resto del laboratorio y a tu LAN (`pve_lan`), y escribe el estado en
las **notas de las VM** en Proxmox. No usa instantáneas: no se pierde nada de lo configurado.
Comprobado: con el modo activo `siem` y `cliente` no salen a Internet, el laboratorio sigue
funcionando por dentro y desde tu equipo sigues entrando a Webmin y Wazuh.

**Límite:** es una medida dentro de las VM. Un alumno con `sudo` en `srv` puede volver a poner la
ruta, y reiniciar `srv` o `siem` la devuelve. Protege de errores, no de quien quiera saltárselo;
para forzarlo desde el host haría falta el cortafuegos de Proxmox. (Quitar el SNAT de las
subredes **no** sirve: se probó y la regla de `iptables` sigue activa en el nodo hasta reiniciarlo.)

## 6. Destruir

```bash
ansible-playbook destruir.yml -e confirmar=lab-servicios
```
Borra **solo** las VM de `lab_vms` que lleven la etiqueta `lab-servicios` en el nodo, y la zona
`labsrv` con sus redes. Conserva la plantilla y la imagen para el siguiente despliegue (bórralas
con `-e borrar_plantilla=si`). Sin `confirmar` no hace nada.

## Limitaciones

- **Un laboratorio por clúster**: las subredes son fijas (las del PDF). Para varios alumnos a la
  vez habría que parametrizar zona, VNets, subredes y VMID por alumno (no incluido).
- Aplicar el SDN recarga la red de todos los nodos del clúster, aunque la zona solo exista en uno.
- 22.44.77.0/24 es un rango público usado como red «NAT», igual que en el PDF: dentro del
  laboratorio esas direcciones reales no son accesibles.
- RAM medida en el despliegue real: el nodo pasa a usar 13,4 GB en total (12 GB asignados a las
  VM más el propio Proxmox).
- Lo que está verificado en un Proxmox real y lo que no: [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md), sección I.
