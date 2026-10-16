# 01 · Guía del docente: servidor compartido

Instalas Ludus **una vez** en un servidor del centro y creas un usuario por
alumno. Cada alumno recibe su rango aislado y su VPN WireGuard.

> Antes de la primera clase completa [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md):
> este repositorio aún no se ha desplegado en un Ludus real.

## 1. Requisitos del servidor

Según la documentación de Ludus (mínimos para el servidor):

| Recurso | Mínimo de Ludus | Nota |
| --- | --- | --- |
| CPU | x86_64 con virtualización (`vmx` o `svm`), Passmark > 6000 | |
| RAM | 32 GB | Esto es para **un** rango |
| Disco | 200 GB, NVMe recomendado | Más 50 GB por rango (clones enlazados) |
| Red | Cable; sin WiFi ni NIC en bonding | |
| SO | Debian 12/13, o Proxmox 8/9 ya instalado | **No** instales Docker en el host |

### Cuántos alumnos caben (estimación, no cifra de Ludus)
Los clones enlazados ahorran **disco**, pero la **RAM** se reparte entera.
Suponiendo ~8 GB de reserva para Proxmox y el router de cada rango:

```
rangos simultáneos ≈ (RAM del host − 8 GB) / RAM por rango
  básico   ≈ 20 GB por alumno      avanzado ≈ 24 GB por alumno
  128 GB  →  6 básicos  o  5 avanzados
  256 GB  → 12 básicos  o 10 avanzados
```
Si hay más alumnos que rangos, haz turnos o trabaja en parejas (un rango por
pareja). Los rangos apagados no consumen RAM.

## 2. Instalar Ludus

Como `root` en el servidor (Debian 12/13), según la guía oficial:

```bash
apt update && apt install curl sudo ca-certificates
curl --proto '=https' --tlsv1.2 -sSf https://ludus.cloud/install | bash
```
El instalador reinicia el equipo y continúa solo. Sigue el progreso con
`ludus-install-status` (como root por SSH). Si prefieres revisar el script antes
de ejecutarlo, descárgalo con `curl https://ludus.cloud/install > install.sh`.

Si ya tienes Proxmox 8/9, sigue la
[guía de despliegue sobre Proxmox](https://docs.ludus.cloud/docs/deployment-options/proxmox).

## 3. Construir las plantillas (una vez)

```bash
ludus templates list                 # al principio todas aparecen "NOT BUILT"
ludus templates build                # puede tardar varias horas
ludus templates status               # progreso
ludus templates logs -f              # logs de Packer
```
Este laboratorio usa estas cuatro (más Kali en el avanzado):

| Plantilla | La usa |
| --- | --- |
| `debian-12-x64-server-template` | siem, web, db |
| `win2022-server-x64-template` | DC01 |
| `win11-22h2-x64-enterprise-template` | WIN11-01 |
| `kali-x64-desktop-template` | kali (avanzado) |

> Las plantillas de Windows se construyen desde **ISO de evaluación**, que
> caducan. Si el curso dura un trimestre completo, reconstruye las plantillas
> antes de empezar y comprueba las fechas de caducidad
> (ver [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md)).

## 4. Crear los usuarios

El CLI de `ludus` debe apuntar al servidor con tu clave de administrador (ver
[Use the CLI locally](https://docs.ludus.cloud/docs/quick-start/using-cli-locally);
la clave raíz se obtiene con `ludus-install-status` en el servidor).
La clave se exporta como variable de entorno: `export LUDUS_API_KEY=...`.

Un usuario por alumno (o por pareja), con ID corto de 2–3 letras:

```bash
ludus user add --name "Ana Pérez" --userid AP --email ana@centro.es
```
Ludus pregunta la contraseña (déjala vacía para que genere una aleatoria) y
muestra la **API key** del usuario. Entrégasela al alumno por un canal privado.
Para obtener su VPN:

```bash
ludus user wireguard --user AP > AP.conf      # entrégaselo al alumno; no lo subas a git
```

> El ID del usuario es el `range_id` que aparece en los nombres de las VMs.

## 5. Preparar lo que comparten todos los alumnos

Cada alumno ejecuta los scripts con **su** API key, incluido
`instalar-roles.sh`: los roles de Ansible se registran **por usuario**. (Si
prefieres instalarlos una sola vez para todos como administrador, consulta la
opción global del CLI; está anotado en [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md).)
Para comprobarlo tú primero, como si fueras un alumno:

```bash
git clone https://github.com/bajoblanco80/lab-siem-ludus.git && cd lab-siem-ludus
scripts/instalar-roles.sh
scripts/preparar-config.sh avanzado
ludus range config set -f rango/range-config-avanzado.local.yml
ludus range deploy
```

## 6. Antes de la primera clase: lista de comprobación

- [ ] Plantillas construidas (`ludus templates list` sin "NOT BUILT").
- [ ] Un despliegue de prueba llega a `SUCCESS` con `ludus range status`.
- [ ] `scripts/verificar-laboratorio.sh` da todo OK en tu prueba.
- [ ] Recorrido por el dashboard de Wazuh y los cinco ataques del avanzado.
- [ ] Completada la lista de [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md).
- [ ] Usuarios creados y VPN entregadas de forma privada.
- [ ] Alumnos informados del [uso responsable](05-uso-responsable.md).

## 7. Durante el curso

| Situación | Qué hacer |
| --- | --- |
| Un alumno rompió su rango | `ludus range deploy` de nuevo, o destruir y redesplegar. Su configuración está en el YAML |
| Quieres ver cómo van todos | Pide a cada alumno el informe de `verificar-laboratorio.sh --informe` |
| Recursos justos | Pídeles apagar su rango al terminar la sesión |
| Reparto de claves | Cada alumno genera sus propias claves con `preparar-config.sh`; tú no las ves |

La evaluación está en [`plantillas/`](../plantillas/).
