# 04 · Solución de problemas

Orden recomendado: **1)** `ludus range status`, **2)** `ludus range logs -f`,
**3)** `scripts/verificar-laboratorio.sh`, **4)** esta tabla.

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| `ludus range deploy` falla con "role not found" | No instalaste los roles en **tu** usuario | `scripts/instalar-roles.sh` y vuelve a desplegar |
| Falla el rol `lab_db` o `lab_web` con "clave vacía o corta" | Cargaste el `.yml` original en vez del `.local.yml` | `scripts/preparar-config.sh <itinerario>` y carga el `.local.yml` |
| Despliegue parado en el rol del SIEM | La instalación de Wazuh tarda 10–20 min | Espera. Si pasa de 60 min, mira `ludus range logs -f` |
| Un agente no aparece en el dashboard | El SIEM no estaba listo, o la IP calculada es incorrecta | En la VM del agente: `systemctl status wazuh-agent` (Linux) o servicio `WazuhSvc` (Windows) y revisa el log del agente |
| Agente "disconnected" tras `ludus testing stop` | La VM se restauró a su instantánea | Espera 1–2 min o reinicia el servicio del agente |
| El agente de Windows no se instala | El despliegue se hizo con el modo de pruebas activo (sin Internet) | `ludus testing stop`, vuelve a desplegar y activa el modo de pruebas después |
| `WIN11-01` sin dominio o sin DNS durante el modo de pruebas | `block_internet` distinto entre el DC y el cliente | Deja ambos con el valor por defecto (no los toques) |
| Dashboard no abre | Certificado autofirmado | Acepta la excepción del navegador; la URL es `https://IP-del-SIEM` |
| No sé la clave del dashboard | Se generó al instalar | En la VM `siem`: `sudo cat /root/wazuh-passwords.txt` |
| La web muestra "Error de base de datos" | `db` no está lista o la IP calculada no coincide | Comprueba `db` (`systemctl status mariadb`) y que la IP de `db` es `.21` en la VLAN 10 |
| El rol `lab_web` falla con el socket de PHP | La versión de PHP del paquete no es la 8.2 | Ajusta `lab_php_version` (Debian 12 = 8.2, Debian 13 = 8.4) en `role_vars` |
| Pierdo mis notas al salir del modo de pruebas | Esa VM se restauró | Guarda siempre las notas en la Kali (no se restaura) o en tu equipo |
| `verificar-laboratorio.sh`: todo "NO VERIFICABLE" | Faltan `WAZUH_API_PASS` o `WEB_IP` | Exporta las variables (ver cabecera del script) |

## Reconstruir sin miedo
Si algo queda en un estado raro, `ludus range deploy` vuelve a aplicar el YAML.
Para partir de cero, destruye el rango y despliega otra vez: el laboratorio es
código, no hay nada que perder salvo tus notas dentro de las VMs.

## Dónde mirar
| Qué | Dónde |
| --- | --- |
| Log del despliegue | `ludus range logs -f` |
| Estado de las VMs | `ludus range status` |
| Log del agente en Linux | `/var/ossec/logs/ossec.log` |
| Log del agente en Windows | `C:\Program Files (x86)\ossec-agent\ossec.log` |
| Log del manager | `/var/ossec/logs/ossec.log` en `siem` |
| Alertas sin procesar | `/var/ossec/logs/alerts/alerts.json` en `siem` |
