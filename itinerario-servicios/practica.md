# Práctica de servicios: montar con Webmin y auditar con Wazuh

**Nivel:** FP / inicial (no hace falta haber hecho el básico) · **Duración:** 3–4 sesiones de
3–4 h · **Entorno:** Proxmox VE sin Ludus (`proxmox/desplegar.yml`, lo despliega el docente)

## Qué vas a aprender
1. Configurar con Webmin los servicios de una red pequeña: router, DHCP, DNS maestro y
   secundario, Samba, Apache con HTTPS y OpenLDAP.
2. Saber qué rastro deja cada servicio y cómo llega ese rastro al SIEM.
3. Provocar eventos y encontrarlos en Wazuh.
4. Escribir una regla propia para lo que Wazuh no reconoce.
5. Endurecer la configuración y medir el cambio.

## Antes de empezar
- **El PDF «Configuración de servicios con Webmin»** te lo entrega el docente (no está en este
  repositorio). Esta guía te dice qué capítulo seguir y **qué cambia** en el laboratorio.
- Lee [docs/00-conceptos.md](../docs/00-conceptos.md): SIEM, agente, evento, alerta, regla y FIM.
- Lee el [uso responsable](../docs/05-uso-responsable.md).
- El docente te da: acceso de red al laboratorio, la clave de `root` de Webmin y la clave de
  `admin` de Wazuh.

## Qué entregas
1. Las capturas y respuestas marcadas con 📝 (S1 a S12).
2. El [informe de auditoría](../plantillas/informe-auditoria.md) con «Itinerario: Servicios».
   Se evalúa con la [rúbrica](../plantillas/rubrica-servicios.md).

## El laboratorio

Es la red del PDF, con las mismas direcciones, más un SIEM. Mapa completo:
[docs/diagramas/mapa-red-servicios.html](../docs/diagramas/mapa-red-servicios.html).

| Máquina | Red (interfaz) | IP | Papel en el PDF |
| --- | --- | --- | --- |
| `srv` | `nat` (`eth0`) y `testlab` (`eth1`) | 22.44.77.250 · 10.20.30.250 | Ubuntu Server |
| `ns2` | `testlab` (`eth0`) | 10.20.30.249 | DNS secundario |
| `cliente` | `testlab` (`eth0`) | 10.20.30.5 | Ubuntu Desktop (aquí sin escritorio) |
| `siem` | `soc` (`eth0`) | 10.20.20.10 | — (Wazuh) |

`testlab` está **aislada**, como la red host-only del PDF: `ns2` y `cliente` no salen a ninguna
parte hasta que configures `srv` como router (Parte 3.1). Por eso, al empezar, sus agentes de
Wazuh aparecen **pendientes** (*pending*) o **desconectados**.

---

## Parte 1 · Conectar (20 min)

**1.1** Comprueba que llegas al laboratorio: `ping -c1 22.44.77.250` y `ping -c1 10.20.20.10`.
Si no responden, pide al docente las rutas ([docs/08](../docs/08-proxmox-nativo.md)).

**1.2** SSH (usuario `labadmin`, con tu clave o la que te indique el docente):
```bash
ssh labadmin@22.44.77.250                              # srv
ssh -J labadmin@22.44.77.250 labadmin@10.20.30.249     # ns2, saltando por srv
ssh -J labadmin@22.44.77.250 labadmin@10.20.30.5       # cliente, saltando por srv
```

**1.3** Webmin de `srv`: `https://22.44.77.250:10000`, usuario `root` y la clave que te da el
docente. Acepta el certificado autofirmado. Para el Webmin de `ns2` o `cliente`, que están en
`testlab`, abre un túnel y entra por `https://localhost:10001`:
```bash
ssh -J labadmin@22.44.77.250 -L 10001:localhost:10000 labadmin@10.20.30.5
```

**1.4** Wazuh: `https://10.20.20.10`, usuario `admin`. En **Agents** (o *Endpoints Summary*)
verás `srv` activo y `ns2` y `cliente` pendientes o desconectados.

---

## Parte 2 · Del PDF al laboratorio (15 min)

| En el PDF | En el laboratorio |
| --- | --- |
| Caps. 1 y 2 (p. 6–18): VMware, red `testlab`, instalar Ubuntu Server | **Ya hecho.** Mismas redes en Proxmox y Debian 12 instalado. Sáltalos. |
| Ubuntu Server 24.04 / Ubuntu Desktop | Debian 12: mismos paquetes, mismo Webmin y también netplan. `cliente` no tiene escritorio: sus pruebas se hacen por consola. |
| Interfaces `ens33` (NAT) y `ens34` (`testlab`) | `srv`: `eth0` (`nat`) y `eth1` (`testlab`). `ns2` y `cliente`: `eth0`. |
| Configurar la IP (p. 25–26) | Las IP ya están puestas por cloud-init. **No cambies la IP de `eth0` de `srv`**: perderías el acceso. Si necesitas algo persistente, crea un fichero nuevo (`/etc/netplan/60-lab.yaml`): `50-cloud-init.yaml` lo regenera el sistema. |
| Reenvío de puertos para Webmin (p. 24) | No hace falta: entras directo a `https://22.44.77.250:10000`. |
| Cap. 4, instalar Webmin (p. 31–33) | **Ya instalado** desde el repositorio oficial en `srv`, `ns2` y `cliente`. Sáltalo. |
| Puerta de enlace 22.44.77.2 y DNS 9.9.9.9 | Iguales. |
| Claves de ejemplo del PDF | Usa claves tuyas, y no las pongas en el informe. |

**Una regla para todos los servicios:** cuando instales un servicio, reinicia el agente de esa
máquina (`sudo systemctl restart wazuh-agent`). Así empieza a vigilar sus ficheros de
configuración y sus logs, que antes no existían.

---

## Parte 3 · Montar los servicios con Webmin (2 sesiones)

Sigue el capítulo del PDF indicado. Debajo de cada uno tienes lo que cambia y el **ajuste para
que Wazuh lo vea**.

### 3.1 Router (cap. 3, p. 26–30)
- En `srv`, la salida es `eth0` y la red interna `eth1`. Activa el reenvío y el enmascaramiento
  (MASQUERADE) por `eth0`, y hazlos persistentes como en el PDF.
- En `cliente` y en `ns2`, pon `srv` como puerta de enlace: `sudo ip route add default via
  10.20.30.250` (para que dure tras reiniciar, añádelo en `/etc/netplan/60-lab.yaml` con
  `routes:`; en el DHCP lo anunciarás con la opción `routers`).
- **Ajuste para Wazuh:** registra en el log lo que el router rechaza. Antes de una regla que
  descarte tráfico, añade otra igual con `-j LOG --log-prefix "DROP "`. Esas líneas llegan al
  SIEM por el log del kernel.

📝 **S1.** Desde `cliente`, `ping -c2 9.9.9.9` funciona, y en Wazuh `ns2` y `cliente` pasan a
**activos** (en menos de un minuto). Explica por qué antes no lo estaban.

### 3.2 DHCP (cap. 5, p. 34–45)
- En `srv`, escucha solo en `eth1`. Subred 10.20.30.0/24, rango del PDF (por ejemplo
  10.20.30.100–10.20.30.200), `routers` 10.20.30.250 y, cuando tengas DNS, `domain-name-servers`
  10.20.30.250. Crea la reserva para `cliente`.
- Para comprobarlo **sin cambiar la IP de `cliente`**:
  `sudo nmap --script broadcast-dhcp-discover -e eth0` (desde `cliente`). Debe aparecer la
  oferta de `srv` con la IP, la puerta de enlace y el DNS.
- **Para Wazuh:** `dhcpd` escribe en `/var/log/syslog`, pero Wazuh no trae decoder para él
  (lo usarás en la Parte 7).

📝 **S2.** Captura de la salida de `nmap` con la oferta de `srv`.

### 3.3 DNS maestro (cap. 6, p. 46–66)
- En `srv`: zona directa `dominio.es` e inversa `30.20.10.in-addr.arpa`, con registros A para
  `srv`, `ns2` y `cliente`, y reenviador 9.9.9.9.
- **Ajuste para Wazuh:** que `named` registre la seguridad y las transferencias. Añade a
  `/etc/bind/named.conf.local` (o desde Webmin, *Logging and Errors*):
  ```
  logging {
      channel wazuh_syslog { syslog daemon; severity info; };
      category security { wazuh_syslog; };
      category xfer-out { wazuh_syslog; };
  };
  ```
  Comprueba con `sudo named-checkconf` y reinicia `bind9`.
- Transferencias de zona (p. 64–66): permite AXFR **solo** hacia 10.20.30.249 (`ns2`).

📝 **S3.** Desde `cliente`: `dig @10.20.30.250 ns2.dominio.es` y `dig @10.20.30.250 -x 10.20.30.5`.

### 3.4 DNS secundario (p. 67–71)
- En `ns2` (Webmin por túnel o consola): zona esclava `dominio.es` con maestro 10.20.30.250.

📝 **S4.** Desde `ns2`, `dig AXFR dominio.es @10.20.30.250` devuelve la zona; desde `cliente`
la misma orden da *Transfer failed*. ¿Qué regla lo decide?

### 3.5 Samba (cap. 7, p. 72–83)
- Recurso compartido y usuario como en el PDF.
- **Ajuste para Wazuh:** en `[global]`, `logging = syslog@1 file`. Por defecto Debian solo
  escribe en `/var/log/samba/`, y Wazuh entiende `smbd` por syslog.

📝 **S5.** Desde `cliente`: `smbclient -L //10.20.30.250 -U <usuario>` lista el recurso.

### 3.6 Apache, VirtualHosts y HTTPS (cap. 8, p. 84–99)
- VirtualHost `www.sitios.net` con su zona DNS (p. 88) y HTTPS (p. 96).
- **Para Wazuh:** los logs `/var/log/apache2/access.log` y `error.log` ya los lee el agente.

📝 **S6.** Desde `cliente`:
`curl -k --resolve www.sitios.net:443:10.20.30.250 https://www.sitios.net/` devuelve tu página.

### 3.7 OpenLDAP (cap. 15, p. 100–119)
- Servidor en `srv` con `dc=dominio,dc=es` (p. 106–112) y alias `ldap.dominio.es` (p. 113).
- Cliente LDAP en `cliente` (p. 113–119) con el Webmin de `cliente` (túnel de 1.3).
- **Ajuste para Wazuh:** que `slapd` registre conexiones y resultados:
  ```bash
  sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<'EOF'
  dn: cn=config
  changetype: modify
  replace: olcLogLevel
  olcLogLevel: stats
  EOF
  ```

📝 **S7.** Inicio de sesión **por consola** de un usuario LDAP en `cliente`
(`su - <usuario>` o `ssh <usuario>@10.20.30.5` saltando por `srv`).

---

## Parte 4 · Comprobar que todo reporta (15 min)

**4.1** En Wazuh, los tres agentes (`srv`, `ns2`, `cliente`) aparecen activos.

**4.2** Con la clave de la API de Wazuh que te da el docente (o léela en `siem` con
`sudo cat /root/wazuh-passwords.txt`):
```bash
export SIEM_IP=10.20.20.10 WAZUH_API_PASS='<clave del usuario wazuh>'
scripts/verificar-laboratorio.sh --itinerario servicios --informe estado.md
```

---

## Parte 5 · Modo de pruebas (5 min)

Antes de cualquier prueba ofensiva, el docente activa el modo de pruebas:
`ansible-playbook modo-pruebas.yml -e estado=activar`. Quita la ruta por defecto de `srv` y
`siem`: el laboratorio deja de salir a Internet, por dentro todo sigue funcionando y no se pierde
nada de lo configurado. Lo verás en las notas de la VM en Proxmox. **No** vuelvas a poner la ruta
por defecto en `srv` mientras esté activo: es la medida que mantiene tus pruebas dentro del
laboratorio.

---

## Parte 6 · Provocar eventos y encontrarlos (1 sesión)

Haz cada acción (desde `cliente` salvo que se indique otra cosa) y búscala en Wazuh (*Threat
Hunting* o *Discover*, filtrando por `agent.name`). Las reglas son las de serie de Wazuh 4.14:
**confírmalas en tu versión** y anota las que salgan distintas.

| # | Acción | Servicio | Regla esperada |
| --- | --- | --- | --- |
| A | `dig AXFR dominio.es @10.20.30.250` | named (`srv`) | 12102 o 12145 (transferencia denegada) |
| B | 3 veces: `ldapwhoami -x -H ldap://10.20.30.250 -D "cn=admin,dc=dominio,dc=es" -w mala` | slapd (`srv`) | 2509 (credenciales inválidas, `err=49`) |
| C | `smbclient //10.20.30.250/<recurso> -U <usuario>%mala` | smbd (`srv`) | 13102/13104 o ninguna: explica por qué |
| D | `curl -k "https://10.20.30.250/?id=1%27%20OR%20%271%27=%271"` | Apache (`srv`) | 31103 o 31104 (ataque web) |
| E | 15 veces: `curl -k https://10.20.30.250/no-existe` | Apache (`srv`) | Grupo 311xx (errores 4xx repetidos) |
| F | 3 inicios de sesión fallidos en el Webmin de `srv` | Webmin | **Ninguna** (no hay decoder) |
| G | En `srv`, cambia un registro en el fichero de zona de `dominio.es` | FIM (`srv`) | 550 (integridad modificada) |
| H | 3 veces: `ssh <usuario LDAP>@10.20.30.5` con clave mala (saltando por `srv`) | sshd/PAM (`cliente`) | 5760 o 5716 |
| I | `sudo nmap --script broadcast-dhcp-discover -e eth0` | dhcpd (`srv`) | **Ninguna** (no hay decoder) |

> Las alertas de FIM muestran **qué cambió** dentro del fichero (`syscheck.diff`). Los ficheros
> con claves (`nslcd.conf`, `*.key`, `miniserv.users`, `slapd.d`) están configurados para no
> enseñarlo, pero si en una alerta ves una clave, no la captures.

📝 **S8.** Completa la tabla con `rule.id`, nivel y una captura por fila.
📝 **S9.** ¿Qué acciones dejan un **evento** pero no una **alerta**? ¿Por qué?
📝 **S10.** Para F e I: ¿dónde está el rastro (fichero y línea) y por qué Wazuh no lo entiende?

---

## Parte 7 · Tu propia regla (45–60 min)

Elige **F (Webmin)** o **I (DHCP)**: Wazuh recibe esas líneas, pero no tiene decoder para
ellas.

**7.1** En `srv`, copia una línea real del rastro: `sudo grep webmin /var/log/auth.log | tail`
(Webmin registra con la *facility* `auth`) o `grep dhcpd /var/log/syslog | tail`. El agente no
lee esos ficheros sino el journal de systemd, que recibe las mismas líneas.

**7.2** En `siem`, pruébala: `sudo /var/ossec/bin/wazuh-logtest`, pega la línea y mira hasta
qué fase llega (pre-decoding, decoding, rule).

**7.3** Fíjate en la fase 2: con la línea de Webmin, Wazuh aplica un decoder **de serie de otro
producto** (en 4.14.11, `barracuda-svf-admin`) y ninguna regla. Un decoder propio no ganaría a
ese, así que la regla no usa `decoded_as`: filtra por `program_name` y el texto. Escríbela (id
`100200` o superior) en `/var/ossec/etc/rules/local_rules.xml`. Esqueleto para Webmin, probado
con una línea real:
```xml
<group name="local,webmin,">
  <rule id="100200" level="5">
    <program_name>^webmin$</program_name>
    <match>Invalid login as</match>
    <description>Webmin: inicio de sesión fallido</description>
  </rule>
</group>
```
Para dhcpd, mira primero qué decoder aplica Wazuh a tu línea y decide si necesitas uno propio
en `/var/ossec/etc/decoders/local_decoder.xml`. Prueba con `wazuh-logtest` hasta ver
*Alert to be generated*, reinicia el gestor (`sudo systemctl restart wazuh-manager`) y repite
la acción. Para ir más allá, añade una segunda regla que salte con varios fallos seguidos desde
la misma IP (`frequency`, `timeframe`, `same_source_ip`).

📝 **S11.** XML final, salida de `wazuh-logtest` con tu regla y la alerta en el panel. Una línea
sobre posibles falsos positivos.

---

## Parte 8 · Endurecer y medir (45–60 min)

Elige **tres** correcciones, aplícalas con Webmin y repite la acción de la Parte 6 que
corresponda para medir el cambio:

| Corrección | Cómo medir |
| --- | --- |
| AXFR solo hacia `ns2` (si aún no) | A desde `cliente` denegada; desde `ns2`, permitida |
| Webmin solo desde ciertas IP (*Webmin Configuration → IP Access Control*) | F desde una IP no permitida ni siquiera llega al formulario |
| Samba sin acceso de invitado y solo para un grupo | C con un usuario fuera del grupo |
| LDAP sin bind anónimo (`olcDisallows: bind_anon`) | `ldapsearch -x -H ldap://10.20.30.250 -b dc=dominio,dc=es` sin credenciales falla |
| Cortafuegos en `srv` que solo deja los puertos de los servicios | `nmap 10.20.30.250` desde `cliente`, antes y después |
| Apache: redirigir HTTP a HTTPS | `curl -I http://...` devuelve 301 |

Además, mira en Wazuh **Configuration Assessment (SCA)** la puntuación de `srv` antes y después.

📝 **S12.** Tabla antes/después de las tres correcciones, con la evidencia de Wazuh.

---

## Parte 9 · Informe (30 min)
Completa el [informe de auditoría](../plantillas/informe-auditoria.md): alcance (`srv`, `ns2`,
`cliente`), hallazgos (al menos 3), tabla de detección con tu Parte 6, regla propia y antes y
después. Sin claves ni capturas que las muestren.

## Al terminar
- Avisa al docente para que desactive el modo de pruebas o destruya el laboratorio
  (`ansible-playbook destruir.yml -e confirmar=lab-servicios`).
- Guarda tus ficheros de configuración si los quieres conservar: al destruir el laboratorio se
  pierden.
