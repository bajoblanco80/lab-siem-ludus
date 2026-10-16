# Práctica básica: desplegar, vigilar y auditar un laboratorio

**Nivel:** FP / inicial · **Duración:** 2 sesiones de 3–4 h (el despliegue ocupa
mucho tiempo de espera) · **Rango:** `range-config-basico.yml`

## Qué vas a aprender
1. Describir una infraestructura como código y desplegarla con un comando.
2. Comprobar que cada servicio está vivo y que cada equipo **reporta su estado** al SIEM.
3. Leer el panel de Wazuh: agentes, eventos y módulos de auditoría.
4. Provocar eventos y localizarlos en el SIEM.
5. Auditar la configuración de un servidor, corregir un hallazgo y volver a medir.

## Antes de empezar
- Has leído [docs/00-conceptos.md](../docs/00-conceptos.md).
- Tienes un usuario de Ludus (te lo da el docente) o has montado tu propio servidor
  ([guía autoalojada](../docs/02-guia-autoalojada.md)).
- Tu CLI de `ludus` funciona: `ludus range status` no da error.
- Conoces el [uso responsable](../docs/05-uso-responsable.md).

## Qué entregas
1. `estado.md` generado por `verificar-laboratorio.sh --informe` (Parte 3).
2. Las capturas y respuestas marcadas con 📝.
3. El [informe de auditoría](../plantillas/informe-auditoria.md) completado (Parte 7).

---

## Parte 1 · Preparación (30 min)

**1.1** Clona el repositorio y entra en él.
```bash
git clone https://github.com/bajoblanco80/lab-siem-ludus.git && cd lab-siem-ludus
```

**1.2** Registra los roles de Ansible en tu usuario de Ludus.
```bash
scripts/instalar-roles.sh
```
✅ *Comprobación:* al final aparece una lista con `lab_wazuh_server`, `lab_wazuh_agent`, `lab_web` y `lab_db`.

**1.3** Genera tu configuración con claves aleatorias.
```bash
scripts/preparar-config.sh basico
```
Se crea `rango/range-config-basico.local.yml`. **Ábrelo y léelo.** Ese archivo
**es** tu laboratorio.

📝 **P1.** En el YAML, ¿qué máquinas hay y en qué VLAN está cada una? ¿Qué
significa `depends_on` en el rol `lab_wazuh_agent` y qué pasaría sin él?

📝 **P2.** ¿Por qué el archivo original `range-config-basico.yml` no tiene claves
y el `.local.yml` sí? ¿Qué hace `.gitignore` con el segundo?

**1.4** Comprueba que las plantillas están construidas.
```bash
ludus templates list
```
✅ Las 3 que usa este laboratorio (`debian-12-x64-server-template`,
`win2022-server-x64-template`, `win11-22h2-x64-enterprise-template`) no deben
poner "NOT BUILT". Si alguna lo pone, avisa al docente.

---

## Parte 2 · Desplegar (40–90 min, sobre todo espera)

```bash
ludus range config set -f rango/range-config-basico.local.yml
ludus range deploy
ludus range logs -f
```
Mientras esperas, ve contestando.

📝 **P3.** El despliegue pasa por tres capas (imágenes, topología, servicios).
¿En cuál estás ahora mismo cuando ves tareas de Ansible en el log?

📝 **P4.** Cuando el log llegue a la instalación de Wazuh, mide cuánto tarda.
¿Por qué crees que los agentes no se instalan hasta que termina?

✅ **Checkpoint:** `ludus range status` muestra `SUCCESS` y 5 VMs.

---

## Parte 3 · Conectar y comprobar el estado (30 min)

**3.1** Entra en tu rango por VPN.
```bash
ludus user wireguard | tee ludus.conf
sudo wg-quick up ./ludus.conf
```
**No subas `ludus.conf` a git** (el `.gitignore` lo evita, pero compruébalo).

**3.2** Averigua las IP de tu rango con `ludus range status` (columna *IP*).
La del SIEM termina en `.20.10`, la del servidor web en `.10.20`.

**3.3** Obtén la clave del dashboard. Conéctate por SSH a la VM `siem` (el
usuario y la clave de las plantillas de Ludus están en su documentación; anótalos
en tu cuaderno) y ejecuta:
```bash
sudo cat /root/wazuh-passwords.txt
```
Ahí están las claves generadas al instalar Wazuh. **No las copies al
repositorio ni a tu informe.**

**3.4** Ejecuta la comprobación de estado desde tu equipo (con la VPN activa).
```bash
export SIEM_IP=<IP-del-siem>
export WEB_IP=<IP-del-web>
export WAZUH_API_PASS='<clave de la API del fichero anterior>'
# Si el usuario de la API que aparece en el fichero no es "wazuh":
# export WAZUH_API_USER='<usuario>'
scripts/verificar-laboratorio.sh --informe estado.md
```
Cada línea es `OK`, `FALLO` o `NO VERIFICABLE`. El script comprueba puertos del
SIEM, la web y que los **4 agentes** (`DC01`, `web`, `db`, `WIN11-01`) están
`active`.

✅ **Checkpoint:** todo `OK`. Si hay `FALLO`, mira [docs/04-solucion-problemas.md](../docs/04-solucion-problemas.md).

📝 **P5.** Adjunta `estado.md`. ¿Qué diferencia hay entre `FALLO` y `NO VERIFICABLE`?
¿Qué línea te demuestra que un equipo "reporta su estado" y no solo que está encendido?

---

## Parte 4 · Recorrido por el dashboard (30 min)

Abre `https://<IP-del-siem>` (acepta la excepción del certificado) y entra con
el usuario `admin` y la clave del fichero.

> Los nombres de los menús pueden variar un poco entre versiones de Wazuh.

| Tarea | Dónde |
| --- | --- |
| Ver los agentes conectados | *Endpoints* → *Agents* (o *Endpoints Summary*) |
| Ver eventos y alertas | *Threat Hunting* (eventos de seguridad) |
| Cambios en archivos | *File Integrity Monitoring* |
| Auditoría de configuración | *Configuration Assessment* |
| Software con vulnerabilidades | *Vulnerability Detection* |
| Técnicas de ataque | *MITRE ATT&CK* |

📝 **P6.** Rellena una tabla con los 4 agentes: nombre, sistema operativo, IP y
versión del agente. ¿Aparece el SIEM como agente? ¿Por qué?

📝 **P7.** Capturas del *Threat Hunting* de las últimas 24 h. ¿Qué alertas ya
hay *antes* de que hayas hecho nada? ¿Son preocupantes?

---

## Parte 5 · Provocar eventos y encontrarlos (45 min)

Vas a generar actividad **normal e inofensiva** y comprobar que el SIEM la ve.
Para cada acción: hazla, espera 1–2 minutos y búscala.

| # | Acción | Dónde mirar | Qué anotar |
| --- | --- | --- | --- |
| A | Intenta entrar por SSH en `web` con un usuario que no existe: `ssh nadie@<IP-web>` (3 veces) | *Threat Hunting*, filtra `agent.name: web` | Descripción de la alerta, nivel y `rule.id` |
| B | En `web`, crea un archivo: `sudo touch /var/www/tienda/prueba.txt` | *File Integrity Monitoring* | Qué dice Wazuh del archivo nuevo |
| C | En `web`, añade un comentario HTML a `/var/www/tienda/index.php` | *File Integrity Monitoring* | Qué cambió (¿ves el diff?) |
| D | En `WIN11-01`, bloquea la sesión e introduce una clave **incorrecta** 3 veces | *Threat Hunting*, filtra `agent.name: WIN11-01` | Evento de inicio de sesión fallido |
| E | En `WIN11-01`, crea un usuario local: `net user prueba Cl4ve-Prueba! /add` (en una consola de administrador) | Mismo filtro | Evento de creación de cuenta |
| F | Abre `http://<IP-web>/` y busca "Teclado" | *Threat Hunting*, filtra `agent.name: web` | ¿Genera alguna alerta? ¿Por qué sí o por qué no? |

📝 **P8.** Para A, D y E rellena: *acción → log donde queda → regla de Wazuh
(`rule.id` y descripción) → nivel*.

📝 **P9.** F es tráfico normal. ¿Quedó **registrado** como evento? ¿Hay **alerta**?
Explica la diferencia entre evento y alerta con este ejemplo.

---

## Parte 6 · Auditoría de configuración (SCA) y corrección (45 min)

Wazuh compara cada equipo con una guía de seguridad y puntúa su configuración.

**6.1** En *Configuration Assessment*, elige el agente `web` y abre el informe de
su política. Anota la **puntuación** y el número de comprobaciones fallidas.

**6.2** Elige **3 comprobaciones fallidas** de `web`. Para cada una anota:
título, qué se comprueba, **por qué importa** (riesgo), cómo se corregiría y la
evidencia (captura).

**6.3** Corrige **una** de las tres en la VM `web` (la más sencilla y segura).
Vuelve a lanzar la evaluación reiniciando el agente:
```bash
sudo systemctl restart wazuh-agent
```
Espera unos minutos y recarga el informe.

📝 **P10.** ¿Cambió la comprobación que corregiste a "passed"? ¿Cambió la
puntuación? Si no, ¿qué crees que pasó?

**6.4** Repite 6.1 con el agente `db` y compara.

📝 **P11.** ¿Qué servidor tiene mejor puntuación y por qué? Mira
*Vulnerability Detection*: ¿hay paquetes vulnerables? ¿Cuál corregirías primero?

---

## Parte 7 · Informe (30 min)

1. Genera de nuevo el informe de estado: `scripts/verificar-laboratorio.sh --informe estado-final.md`.
2. Completa [`plantillas/informe-auditoria.md`](../plantillas/informe-auditoria.md)
   con los hallazgos de la Parte 6.
3. Entrega: `estado.md`, `estado-final.md`, el informe y las respuestas P1–P11.

Tu trabajo se evalúa con [`rubrica-basico.md`](../plantillas/rubrica-basico.md).

## Al terminar
Apaga las VMs para liberar recursos del servidor (consulta `ludus power --help`
o pregunta al docente). **No** destruyas el rango hasta que te lo corrijan.
