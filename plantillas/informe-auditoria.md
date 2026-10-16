# Informe de auditoría del laboratorio

| | |
| --- | --- |
| Alumno/a | |
| Itinerario | Básico / Avanzado |
| Fecha | |
| Versión de Wazuh | |
| Entorno (servidor, ID de rango) | |

> No incluyas claves, tokens ni perfiles VPN en este informe. Si una captura los
> muestra, tápalos.

## 1. Resumen ejecutivo
*(Máx. 10 líneas: qué se auditó, qué se encontró de más importante y qué se recomienda.)*

## 2. Alcance y entorno
Máquinas auditadas, sistema operativo y función de cada una.

| Máquina | SO | Función | Agente Wazuh (versión / estado) |
| --- | --- | --- | --- |
| DC01 | Windows Server 2022 | Controlador de dominio | |
| web | Debian 12 | Servidor web | |
| db | Debian 12 | Base de datos | |
| WIN11-01 | Windows 11 | Cliente | |

Adjunta el informe de `scripts/verificar-laboratorio.sh --informe`.

## 3. Línea base
Estado antes de actuar: alertas por nivel, puntuación SCA por equipo, paquetes vulnerables.

## 4. Hallazgos

Un bloque por hallazgo (mínimo: 3 en el básico, 5 en el avanzado).

### H-01 · *Título corto*
| Campo | Detalle |
| --- | --- |
| Equipo afectado | |
| Fuente | SCA / FIM / Vulnerabilidades / Alerta / Ataque simulado |
| Evidencia | *(captura o línea de log, sin secretos)* |
| Riesgo | Alto / Medio / Bajo y por qué |
| Técnica MITRE ATT&CK (si aplica) | |
| Recomendación | |
| Estado | Abierto / Corregido (con evidencia de la corrección) |

## 5. Detección: qué vio el SIEM y qué no *(avanzado)*
| Ataque | ¿Evento? | ¿Alerta? | `rule.id` / nivel | Tiempo hasta la alerta | Motivo si no hubo alerta |
| --- | --- | --- | --- | --- | --- |
| C1 | | | | | |
| C2 | | | | | |
| C3 | | | | | |
| C4 | | | | | |
| C5 | | | | | |

## 6. Regla propia *(avanzado)*
XML de la regla, salida de `wazuh-logtest`, alerta en el dashboard y análisis de falsos positivos.

## 7. Antes y después
| Métrica | Antes | Después |
| --- | --- | --- |
| | | |

## 8. Recomendaciones priorizadas
Ordenadas por relación riesgo reducido / esfuerzo.

## 9. Limitaciones
Qué no cubre esta auditoría ni este laboratorio.
