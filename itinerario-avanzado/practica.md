# Práctica avanzada: atacar, detectar y endurecer

**Nivel:** Grado / Máster · **Duración:** 3–4 sesiones · **Rango:** `range-config-avanzado.yml` (añade la Kali)

Aquí no basta con ver que el SIEM funciona: tienes que **demostrar qué ve y qué
no ve**, mejorar su detección y medir el efecto de endurecer los sistemas.

> ⚠️ **Todo ataque, solo dentro de tu rango y con el modo de pruebas activo.**
> Lee [docs/05-uso-responsable.md](../docs/05-uso-responsable.md). Los ataques de
> esta práctica son deliberadamente simples y dirigidos a la aplicación de
> ejemplo del propio laboratorio.

## Objetivos
1. Desplegar y verificar el laboratorio completo con código.
2. Ejecutar cinco ataques controlados y **rastrear cada uno** hasta su alerta
   (o demostrar que no la hay).
3. Escribir y probar una **regla propia** con `wazuh-logtest`.
4. Endurecer y **medir** el antes y el después.
5. Redactar un informe técnico con mapeo MITRE ATT&CK.

## Requisitos previos
- Haber completado (o dominar) el [itinerario básico](../itinerario-basico/practica.md).
- Conocimientos de Linux, redes y HTTP.

## Qué entregas
Informe final basado en [`plantillas/informe-auditoria.md`](../plantillas/informe-auditoria.md)
más las fichas de rastreo (Parte C), la regla propia (Parte D) y la tabla de
antes/después (Parte E). Se evalúa con [`rubrica-avanzado.md`](../plantillas/rubrica-avanzado.md).

---

## Parte A · Desplegar y establecer la línea base (1 sesión)

```bash
scripts/instalar-roles.sh
scripts/preparar-config.sh avanzado
ludus range config set -f rango/range-config-avanzado.local.yml
ludus range deploy && ludus range logs -f
```
Conéctate por VPN, obtén la clave del dashboard y verifica (igual que en las
Partes 3 y 4 del básico):
```bash
export SIEM_IP=<ip-siem> WEB_IP=<ip-web> WAZUH_API_PASS='<clave>'
scripts/verificar-laboratorio.sh --itinerario avanzado --informe estado-base.md
```

**Línea base** (guárdala, la necesitas en la Parte E). Anota en una tabla:
- Nº de alertas de las últimas 24 h por nivel (bajo / medio / alto).
- Puntuación SCA de `web` y de `db`.
- Nº de paquetes vulnerables en `web` y en `db`.

> Si activas el modo de pruebas **antes** de que el despliegue termine, los
> agentes de Windows no podrán descargarse. Despliega primero, ataca después.

## Parte B · Modo de pruebas (15 min)

```bash
ludus testing start
ludus testing status
```
Qué hace: hace una instantánea de las VMs y bloquea su salida a Internet.
`ludus testing stop` **restaura** las VMs a esa instantánea. El SIEM y la Kali
están configurados **sin instantánea**: conservan alertas y notas.

📝 **B1.** ¿Qué máquinas perderían su estado al ejecutar `ludus testing stop`?
¿Por qué el SIEM no debe perderlo? ¿Y la Kali?

---

## Parte C · Cinco ataques, cinco rastros (1–2 sesiones)

Trabaja desde la **Kali** (KasmVNC en `https://<IP-kali>:8444/`, o SSH). Sustituye
`WEB`, `DC` y `SIEM` por las IP de tu rango. Para **cada** ataque rellena una
**ficha de rastreo**:

| Campo | Contenido |
| --- | --- |
| Hora exacta del ataque | |
| Comando ejecutado | |
| Evidencia en la víctima (la línea de log que lo prueba) | |
| ¿Llegó al SIEM como **evento**? ¿Como **alerta**? | |
| `rule.id`, descripción y nivel | |
| Técnica MITRE | |
| Tiempo hasta la alerta | |
| Si no hubo alerta: por qué | |

Consulta el **mapa de detección esperado** en [docs/03-arquitectura.md](../docs/03-arquitectura.md).
Las reglas esperadas son una guía: confirma en tu Wazuh cuál saltó de verdad.

### C1 · Descubrimiento de directorios web
```bash
dirb http://WEB/            # o: gobuster dir -u http://WEB/ -w /usr/share/wordlists/dirb/common.txt
```
Verás en el `access.log` de `web` muchas peticiones con respuesta 404 desde una
misma IP. 📝 ¿Alerta o solo eventos?

### C2 · Fuerza bruta contra SSH
Prepara una lista **corta** (20 claves) para no saturar el rango:
```bash
printf '%s\n' admin 123456 password qwerty letmein welcome abc123 root toor changeme > claves.txt
hydra -l root -P claves.txt -t 4 ssh://WEB
```
Busca los intentos en `/var/log/auth.log` de `web` y en el SIEM. 📝 ¿A partir de
qué intento sube el nivel de la alerta?

### C3 · Inyección SQL
```bash
# 1) Extraer usuarios de otra tabla con UNION
curl -G "http://WEB/index.php" --data-urlencode "q=x' UNION SELECT usuario, clave FROM usuarios -- -"

# 2) Saltarse el login
curl -s -X POST "http://WEB/login.php" --data-urlencode "usuario=admin' -- -" --data-urlencode "clave=cualquiera"
```
📝 Aparte de la ficha: ¿qué ve el **atacante** (datos) y qué ve el **defensor**
(líneas de `access.log`)? ¿Dónde quedan las consultas SQL completas? ¿Las ve Wazuh?

### C4 · Password spraying contra el dominio
Una clave común probada contra varios usuarios (evita bloquear cuentas):
```bash
printf '%s\n' alumno labadmin administrator invitado > usuarios.txt
netexec smb DC -u usuarios.txt -p 'Password123!' -d lab.local --continue-on-success
```
El Registro de seguridad de `DC01` anota un evento 4625 por cada fallo.
📝 ¿Qué distingue un *spray* (1 clave, N usuarios) de una fuerza bruta clásica
(1 usuario, N claves) en los eventos? ¿Detecta el SIEM ese patrón?

### C5 · Manipulación de archivos de la aplicación
Simula un atacante que ya tiene acceso y modifica la web (desde tu SSH a `web`):
```bash
echo '<!-- defaced -->' | sudo tee -a /var/www/tienda/index.php
sudo touch /var/www/tienda/shell.php
```
📝 ¿Qué alertas FIM aparecen? ¿Ves el contenido añadido? ¿Qué pasaría si el
atacante modificase el archivo y luego restaurase su contenido y fecha original?

### Entrega de la Parte C
Cinco fichas completas y una tabla-resumen: qué ataques generaron alerta, cuáles
solo eventos y cuáles nada, con el motivo.

---

## Parte D · Tu propia regla de detección (45–60 min)

La inyección con `UNION SELECT` (C3) puede no destacar con las reglas estándar.
Vas a escribir una regla que la detecte **con un nivel alto**.

**D1.** Obtén de `access.log` de `web` la línea real de tu ataque C3:
```bash
sudo grep -i "union" /var/log/nginx/access.log | tail -1
```

**D2.** En la VM `siem`, ejecuta `wazuh-logtest`, pega esa línea y observa qué
decodificador la lee y qué regla salta (si salta alguna).
```bash
sudo /var/ossec/bin/wazuh-logtest
```
📝 **D2.** Anota la salida de las fases 1 (pre-decoding), 2 (decoding) y 3 (rules).

**D3.** Crea una regla local en `/var/ossec/etc/rules/local_rules.xml`. Parte de
este esqueleto y **comprueba con `wazuh-logtest`** el identificador de la regla
padre que corresponde a los accesos web en tu versión (el `if_sid`):
```xml
<group name="web,attack,sql_injection,lab,">
  <rule id="100100" level="12">
    <if_sid>31100</if_sid>
    <regex type="pcre2">(?i)union(\s|%20|\+)+select</regex>
    <description>LAB: UNION SELECT en una petición web</description>
    <mitre><id>T1190</id></mitre>
  </rule>
</group>
```
**D4.** Vuelve a probar con `wazuh-logtest`: debe saltar tu regla `100100`.
Después reinicia el manager y repite el ataque C3:
```bash
sudo systemctl restart wazuh-manager
```
📝 **D4.** Comprueba en el dashboard que aparece la alerta `100100`. Prueba también
con una petición **legítima** que contenga la palabra "union" sin ser ataque:
¿hay falso positivo? Ajusta la expresión si hace falta.

---

## Parte E · Endurecer y medir (45–60 min)

Elige **dos** correcciones, aplícalas y repite el ataque correspondiente.

| Opción | Cómo | Ataque a repetir |
| --- | --- | --- |
| Corregir la inyección SQL | Cambia `index.php` y `login.php` en `web` a consultas **preparadas** (`$db->prepare(...)`, `bind_param`) | C3 |
| Limitar SSH | En `/etc/ssh/sshd_config` pon `MaxAuthTries 3` y `PermitRootLogin no`; recarga `sshd` | C2 |
| Auditoría de configuración | Corrige las 3 comprobaciones SCA más graves de `web` | (re-escanear) |

**Medida antes/después** (rellena):

| Métrica | Antes | Después |
| --- | --- | --- |
| El ataque ¿funciona? (sí/no, evidencia) | | |
| ¿Genera alerta? ¿Cuál? | | |
| Puntuación SCA de `web` | | |
| Alertas nuevas en el SIEM por la corrección | | |

📝 **E1.** Corregir el código en `web` ¿generó alertas FIM? ¿Por qué es
importante distinguir un cambio legítimo de uno malicioso en FIM?

📝 **E2.** ¿Qué corrección redujo más riesgo por menos esfuerzo? Justifícalo.

---

## Parte F · Informe técnico

Usa [`plantillas/informe-auditoria.md`](../plantillas/informe-auditoria.md) e incluye:
1. Resumen ejecutivo (máx. 10 líneas).
2. Línea base (Parte A).
3. Las cinco fichas y la tabla-resumen (Parte C), con **mapeo MITRE ATT&CK**.
4. La regla `100100`, su prueba y el análisis de falsos positivos.
5. La tabla antes/después y las recomendaciones priorizadas.
6. **Limitaciones**: qué *no* detectó el laboratorio y qué faltaría
   (IDS de red, Sysmon, auditoría de Kerberos, correlación entre hosts).

## Ampliaciones voluntarias
- **Kerberoasting / DCSync.** Requieren cuentas con SPN, auditoría de Kerberos y
  Sysmon. Investiga qué habría que añadir y proponlo como una ampliación del rol.
- **Respuesta activa.** Configura una *active response* que bloquee la IP de la
  Kali tras la fuerza bruta SSH. Documenta el riesgo de bloquear por error.
- **Archivar todos los eventos** para poder buscar los que no generaron alerta.
- **Comparar con Elastic Security** como SIEM alternativo (mismo ataque, misma pregunta).

## Al terminar
```bash
ludus testing stop     # las víctimas vuelven a su estado limpio; SIEM y Kali no
```
Guarda **antes** tus notas y capturas fuera de las VMs que se restauran.
