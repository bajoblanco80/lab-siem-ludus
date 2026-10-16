# Rúbrica · Itinerario avanzado (10 puntos)

| Criterio | Peso | Insuficiente (0) | Suficiente (50 %) | Sobresaliente (100 %) |
| --- | --- | --- | --- | --- |
| **Despliegue y línea base** (Parte A) | 1 | Sin línea base | Línea base incompleta | Línea base completa y reproducible |
| **Seguridad operativa** (Parte B) | 1 | Ataca sin modo de pruebas | Modo de pruebas pero sin explicarlo | Lo usa siempre y justifica qué se restaura y qué no (B1) |
| **Rastreo de ataques** (Parte C) | 3 | Menos de 3 fichas | 5 fichas, algunas sin evidencia o sin explicar la ausencia de alerta | 5 fichas con evidencia del log, regla, MITRE y análisis de por qué una detección falla |
| **Regla propia** (Parte D) | 2 | No funciona | Funciona en `wazuh-logtest` | Funciona en el SIEM, con prueba de falsos positivos y ajuste |
| **Endurecimiento y medida** (Parte E) | 2 | Sin medición | Corrige y mide una cosa | Corrige dos, mide antes/después y razona riesgo frente a esfuerzo (E1–E2) |
| **Informe técnico y limitaciones** (Parte F) | 1 | Descriptivo, sin análisis | Completo pero sin limitaciones | Prioriza recomendaciones y señala con criterio qué no cubre el laboratorio |

## Penalizaciones
- **Claves, tokens o `ludus.conf` en la entrega o en git:** −2 puntos.
- **Ataque fuera del rango propio o sin modo de pruebas:** la práctica no se evalúa y se avisa al docente.
