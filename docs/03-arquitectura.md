# 03 · Arquitectura

## Redes y direcciones

Ludus asigna a cada alumno una red `10.<N>.0.0/16` propia (el segundo octeto
`<N>` depende del alumno). Dentro de ella:

| VLAN | Uso | Máquina | Último octeto | IP de ejemplo (N = 2) |
| --- | --- | --- | --- | --- |
| 20 | SOC | `siem` | .10 | 10.2.20.10 |
| 20 | SOC | `kali` (avanzado) | .99 | 10.2.20.99 |
| 10 | Servicios | `DC01` | .10 | 10.2.10.10 |
| 10 | Servicios | `web` | .20 | 10.2.10.20 |
| 10 | Servicios | `db` | .21 | 10.2.10.21 |
| 10 | Servicios | `WIN11-01` | .30 | 10.2.10.30 |

Averigua tu `N` real con `ludus range status` (columna *RANGE NETWORK*).
Entre VLAN el tráfico está permitido (comportamiento por defecto de Ludus), de
modo que la Kali llega a las máquinas de servicios.

### ¿Cómo sabe cada agente dónde está el SIEM?
El rol `lab_wazuh_agent` calcula la IP: toma `10.<N>` de la variable
`ludus_dns_server` que Ludus pasa a todos los roles (siempre es `10.<N>.<vlan>.254`)
y le añade la VLAN y el octeto del SIEM de `global_role_vars`. Si algo falla,
puedes forzarla con `lab_siem_ip` en `role_vars`.

## Flujo de datos de auditoría

```mermaid
flowchart LR
    subgraph fuentes["Fuentes de auditoría"]
        w1["web · access.log de nginx"]
        w2["web · auth.log (SSH)"]
        w3["web · FIM de /var/www/tienda"]
        d1["db · log de auditoría MariaDB"]
        d2["db · auth.log y FIM de /etc/mysql"]
        dc1["DC01 · Registro de seguridad (4625…)"]
        c1["WIN11-01 · Registro de seguridad"]
    end
    ag["Agente Wazuh<br/>(en cada equipo)"]
    mgr["Wazuh manager<br/>decodifica + aplica reglas"]
    idx[("Wazuh indexer")]
    dash["Dashboard<br/>https://IP-del-SIEM"]

    w1 & w2 & w3 & d1 & d2 & dc1 & c1 --> ag
    ag -- "1514/tcp eventos" --> mgr
    ag -. "1515/tcp registro del agente" .-> mgr
    mgr -- "alertas" --> idx --> dash
```

## Orden de despliegue (lo gestiona `depends_on`)

```mermaid
flowchart TD
    A["1 · Ludus crea las VMs y la red<br/>DC01 configura el dominio · WIN11-01 se une"]
    A --> S["2a · siem: lab_wazuh_server<br/>(10–20 min)"]
    A --> P["2b · web y db: lab_web y lab_db<br/>app y datos de ejemplo<br/>(no dependen del SIEM)"]
    S --> C{"¿terminó lab_wazuh_server?<br/>depends_on del agente"}
    C -- "no" --> W["el agente espera"] --> C
    C -- "sí" --> G["3 · lab_wazuh_agent<br/>en DC01, web, db y WIN11-01"]
    P --> G
    G --> F(["SUCCESS en ludus range status"])
```

1. Se crean las VMs y la red; Ludus configura el dominio en `DC01` y une `WIN11-01`.
2. En paralelo: el SIEM instala Wazuh (`lab_wazuh_server`, 10–20 min) y `web` y
   `db` instalan sus servicios (`lab_web`, `lab_db`).
3. El rol `lab_wazuh_agent` de **cada** VM espera a que `lab_wazuh_server` termine
   (`depends_on`). En `web` y `db` se ejecuta además **después** de su rol de
   servicio, para registrar ya los logs de nginx y MariaDB. Sin `depends_on` un
   agente intentaría registrarse antes de que el manager exista.

## Qué decisiones de diseño merece la pena discutir

| Decisión | Motivo |
| --- | --- |
| SIEM en una **VM**, no en LXC | Wazuh interactúa con el kernel (auditoría, descriptores de archivo). Un LXC comparte el del host y da problemas de permisos y de "too many open files" |
| SIEM sin instantánea (`snapshot: false`) | Al salir del modo de pruebas las víctimas se restauran pero las alertas se conservan |
| Web y BD en **VMs separadas** | Permite auditar el acceso entre capas y que la BD solo acepte conexiones del web |
| Roles **propios** de Wazuh | Instalan solo desde `packages.wazuh.com`; no se ejecuta código de terceros como root |
| Versión de Wazuh **fijada** | El agente debe ser ≤ que el manager; todo se documenta contra la misma versión (4.14) |

## Mapa de detección (avanzado)
Cada ataque del itinerario avanzado debe poder rastrearse hasta una alerta. Las
**reglas esperadas** salen de las reglas estándar de Wazuh y deben confirmarse
en tu versión (ver [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md)).

| # | Ataque (desde Kali) | Host | Dónde queda el rastro | Regla esperada | MITRE |
| --- | --- | --- | --- | --- | --- |
| 1 | Escaneo de directorios web | web | `access.log` de nginx (muchos 404) | grupo `web` (31xxx) | T1595 |
| 2 | Fuerza bruta SSH | web | `/var/log/auth.log` | 5710 / 5712 | T1110 |
| 3 | Inyección SQL en `q=` y en el login | web | `access.log` | 31103 | T1190 |
| 4 | Password spraying contra el dominio | DC01 | Registro de seguridad, evento 4625 | 60122 / 60204 | T1110.003 |
| 5 | Modificar `/var/www/tienda/index.php` | web | FIM (syscheck) | 550 / 554 | T1565 |

**Lo que NO se promete:** Kerberoasting, DCSync u otros ataques de identidad.
Requieren cuentas con SPN, auditoría avanzada de Kerberos y Sysmon, que este
laboratorio no configura. Ver "Ampliaciones" en el itinerario avanzado.

## Lo que Wazuh no ve por defecto
- Posiblemente, los eventos de la **BD**: el log de auditoría de MariaDB se
  recoge como texto, pero **puede que** Wazuh no tenga un decodificador para ese
  formato (compruébalo con `wazuh-logtest`, ver
  [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md)). Si no lo tiene,
  aparecerá como evento sin alerta, lo que sirve para el ejercicio de escribir
  una regla propia.
- El **tráfico de red**: no hay IDS de red (Suricata/Zeek) en este laboratorio.
