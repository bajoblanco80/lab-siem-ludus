# Rúbrica · Itinerario servicios (10 puntos)

Montaje de servicios con Webmin (4 puntos) y auditoría con Wazuh (6 puntos).

| Criterio | Peso | Insuficiente (0) | Suficiente (50 %) | Sobresaliente (100 %) |
| --- | --- | --- | --- | --- |
| **Router y DHCP** (Partes 3–4) | 1 | `ns2` y `cliente` siguen sin salida | Router funcionando; agentes de `ns2` y `cliente` en `active` | Además, DHCP sirve concesiones con reserva y lo comprueba con `nmap` (S1–S2) |
| **DNS maestro y secundario** (Parte 3) | 1,5 | Sin zona | Zonas directa e inversa en `srv` | Secundario en `ns2` con transferencia solo hacia `ns2` y comprobada con `dig AXFR` (S3–S4) |
| **Samba, Apache y LDAP** (Parte 3) | 1,5 | Ninguno funciona | Dos de los tres funcionan | Los tres, con HTTPS en un VirtualHost y un usuario LDAP que inicia sesión en `cliente` (S5–S7) |
| **Eventos y lectura del SIEM** (Partes 5–6) | 2 | No localiza eventos | Localiza la mitad de la tabla de la Parte 6 | Localiza todos, con `rule.id` y nivel, y explica los que no generan alerta (S8–S10) |
| **Regla propia** (Parte 7) | 1,5 | Sin regla | Regla que salta en `wazuh-logtest` | Regla (y decoder si hace falta) que salta en el panel, con análisis de falsos positivos (S11) |
| **Endurecer y medir** (Parte 8) | 1,5 | Sin cambios | Dos correcciones sin medir | Tres correcciones con medida antes/después en Wazuh (S12) |
| **Informe y buenas prácticas** (Parte 9) | 1 | Sin informe o con claves a la vista | Informe completo con carencias | Informe claro, sin secretos y con capturas legibles |

## Penalizaciones
- **Claves (Webmin, LDAP, Samba, Wazuh) en la entrega o en git:** −2 puntos.
- Pruebas ofensivas sin el modo de pruebas activo o contra equipos ajenos al laboratorio:
  suspenso de la práctica y aviso al docente.
