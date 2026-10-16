# Verificación pendiente

Este repositorio **no se ha desplegado en un Ludus real**. Esto es lo que sí y lo
que no se ha comprobado, y el comando exacto para comprobar cada punto pendiente.

## Ya comprobado (sin Ludus)

| Qué | Cómo |
| --- | --- |
| Los dos `range-config` cumplen el **esquema oficial** de Ludus | Validados con `jsonschema` contra `https://docs.ludus.cloud/schemas/range-config.json` |
| Coherencia interna: IPs y VLAN únicas, `global_role_vars` = valores de las VMs, `depends_on` apunta a VMs y roles que existen, hostnames de Windows ≤ 15 caracteres | Script de comprobación propio |
| Los 4 roles tienen sintaxis Ansible válida | `ansible-playbook --syntax-check` |
| Los scripts no tienen errores de shell | `bash -n` y `shellcheck` |
| `preparar-config.sh` genera un `.local.yml` válido contra el esquema, con claves complejas, y se niega a sobrescribirlo | Ejecutado |
| `verificar-laboratorio.sh` interpreta bien una API de Wazuh **simulada** (agentes activos, desconectados y ausentes; clave correcta, incorrecta y sin clave; informe en markdown) | Ejecutado contra un servidor HTTPS de pruebas |
| Los comandos del CLI de Ludus usados | Contrastados con la documentación oficial (ver abajo lo que no se pudo) |

## Pendiente: lo hace el docente en un Ludus real

Marca cada casilla y anota la versión de Ludus y de Wazuh con la que lo probaste.
**Versión de Ludus:** ______ · **Versión de Wazuh instalada:** ______ · **Fecha:** ______

### A. Roles y despliegue

- [ ] **Sintaxis del CLI.** La documentación usa `ludus ansible roles add -d <dir> --force`
      (plural); el esquema oficial habla de `ludus ansible role add`.
      `scripts/instalar-roles.sh` usa el plural. Comprueba: `ludus ansible roles list`.
- [ ] **Roles por usuario o globales.** Un administrador puede instalar roles para
      todos los usuarios (`ludus ansible roles add --help`: busca una opción global). Si existe,
      el docente puede evitar que cada alumno ejecute `instalar-roles.sh`.
- [ ] **`ludus_dns_server` disponible** en los roles de Linux **y** de Windows. De él
      sale la IP del SIEM. Prueba: añade `ansible.builtin.debug: var=ludus_dns_server` y despliega.
      Plan B: `lab_siem_ip` en `role_vars`.
- [ ] **El despliegue llega a `SUCCESS`** (`ludus range status`) y se anota el tiempo real
      (la guía estima 40–90 min).
- [ ] **`depends_on` ordena bien.** El SIEM termina antes de que el primer agente arranque.
- [ ] **Credenciales de las plantillas.** Usuario y clave de las VMs (necesarias para el SSH
      de las prácticas) según la documentación de Ludus. Anótalos en las guías.

### B. Wazuh (versión 4.14)

- [ ] El asistente `wazuh-install.sh -a` funciona en Debian 12 con 4 vCPU / 8 GB y termina
      en el tiempo esperado (10–20 min).
- [ ] Las claves quedan en `/root/wazuh-passwords.txt` (extraídas de
      `wazuh-install-files.tar`). **Usuario y clave de la API en ese fichero**: el script
      de verificación asume el usuario `wazuh`; si es otro, documéntalo.
- [ ] El agente se fija con `apt install wazuh-agent=4.14.9-1`. Confirma que esa versión
      existe en el repositorio `4.x` y que es **≤** la del manager (`/var/ossec/bin/wazuh-control info`).
      Si no existe, actualiza `lab_wazuh_agent_version` en los dos `range-config`.
- [ ] El MSI `wazuh-agent-4.14.9-1.msi` existe en `packages.wazuh.com/4.x/windows/`.
- [ ] Los agentes de **Windows** se instalan con `win_package` (espera al MSI) y se registran
      con `WAZUH_MANAGER=...`. Confirma que `win_package` acepta el MSI sin `product_id` y
      que `WazuhSvc` queda en marcha (`Get-Service WazuhSvc`).
- [ ] Los 4 agentes (`DC01`, `web`, `db`, `WIN11-01`) aparecen `active` en
      `scripts/verificar-laboratorio.sh`.

### C. Recogida de logs

- [ ] La configuración por defecto del agente Linux **ya lee `/var/log/auth.log`**
      (si no, añádelo en `lab_wazuh_localfiles`).
- [ ] El `blockinfile` en `/var/ossec/etc/ossec.conf` queda **bien formado**: el agente
      arranca tras añadir `<localfile>` y un segundo bloque `<syscheck>`. Prueba:
      `sudo /var/ossec/bin/wazuh-control status` en `web` y `db`.
- [ ] El agente de Windows envía el **Registro de seguridad** por defecto (eventos 4625, 4720).
- [ ] El formato `apache` decodifica el `access.log` de nginx (`wazuh-logtest`).
- [ ] **MariaDB `server_audit`**: el plugin existe en la versión de MariaDB de Debian 12 y
      escribe en `/var/log/mysql/mariadb-audit.log`. Si no, borra las 4 líneas del
      `60-lab.cnf.j2`. Comprueba además si Wazuh decodifica ese formato (la documentación
      supone que **no**, para el ejercicio de regla propia).
- [ ] En `web`, PHP es 8.2 y existe `/run/php/php8.2-fpm.sock` (si no, `lab_php_version`).

### D. Mapa de detección del itinerario avanzado

Ejecuta cada ataque y anota el `rule.id` que salta en tu versión. Si difiere, corrige
`docs/03-arquitectura.md` y la práctica.

- [ ] C1 escaneo web: grupo `web` (31xxx) → real: ______
- [ ] C2 fuerza bruta SSH: 5710 / 5712 → real: ______
- [ ] C3 inyección SQL: 31103 → real: ______
- [ ] C4 password spraying: 60122 / 60204 → real: ______
- [ ] C5 FIM: 550 / 554 → real: ______
- [ ] **Regla propia**: la regla padre `31100` existe y es la correcta para accesos web;
      la regla `100100` salta en `wazuh-logtest` y en el dashboard.
- [ ] **SCA** produce resultados para Debian 12 y **Vulnerability Detection** está activo
      por defecto en 4.14 (si no, hay que habilitarlo y la Parte 6 del básico cambia).
- [ ] Nombres de los menús del dashboard de 4.14 (la práctica da los habituales).

### E. Modo de pruebas

- [ ] `ludus testing start` / `status` / `stop` se comportan como dice la guía:
      el SIEM y la Kali **no** se restauran; `DC01`, `web`, `db` y `WIN11-01` sí.
- [ ] Con el modo activo, el dominio sigue funcionando (DC y cliente con el mismo valor de `block_internet`).
- [ ] La Kali trae `dirb`/`gobuster`, `hydra` y `netexec` (si falta alguno, ajusta C1, C2 o C4).

### F. Capacidad y licencias

- [ ] Mide la RAM real consumida por un rango básico y uno avanzado y corrige la
      tabla de capacidad de `docs/01-guia-docente.md` (hoy es una **estimación**).
- [ ] **Caducidad de las ISO de evaluación de Windows**: comprueba cuántos días dan las de
      Windows Server 2022 y Windows 11 Enterprise y cuánto dura tu curso.
- [ ] `ludus power --help`: confirma cómo apagar las VMs (la práctica remite a ese comando).

### G. Perfil lite (16 GB)

- [ ] Con `range-config-lite.yml` el despliegue llega a `SUCCESS` en un equipo dedicado de 16 GB.
- [ ] **Wazuh es estable con 6 GB** (indexer, manager y dashboard activos tras 30 min y tras
      generar actividad). Si no, sube `siem` a 7–8 GB y baja `DC01`.
- [ ] **Windows Server 2022 es usable con 3 GB** y el dominio funciona.
- [ ] `web` y `db` con 1 GB instalan sus paquetes y sirven la tienda sin quedarse sin memoria.
- [ ] El router de Ludus funciona con `router: {ram_gb: 1, cpus: 1}`.
- [ ] Mide el consumo real del host (`free -h`) y ajusta la tabla de `docs/06-perfil-lite.md`.
- [ ] `scripts/verificar-laboratorio.sh --itinerario lite` da todo OK con 3 agentes.

## Cosas que NO prometemos
- Kerberoasting, DCSync y otros ataques de identidad (exigen SPN, auditoría de Kerberos y Sysmon).
- Detección de tráfico de red (no hay IDS).
- Una instalación en un equipo con menos de 32 GB de RAM **fuera del perfil lite**, que es experimental.

## Aviso sobre fuentes
El documento de análisis del que parte este laboratorio contiene afirmaciones que
**no se han trasladado** a la práctica sin verificarlas: p. ej. cifras de versiones de
Wazuh/Elastic y el rol comunitario de Wazuh para Ludus (el código real instala
una versión distinta de la que dice su README, descarga un script de un tercero y
el `tasks/main.yml` del rol del agente solo incluye la rama de Windows aunque su
README dice soportar Debian y Ubuntu). Este repositorio instala Wazuh
**solo desde `packages.wazuh.com`** y fija la versión 4.14 según la documentación oficial.
