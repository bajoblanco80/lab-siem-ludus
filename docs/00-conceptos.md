# 00 · Conceptos previos

Léelo antes de empezar. Si ya conoces un término, sáltalo.

## Infraestructura como código (IaC)
En lugar de crear máquinas a mano con un asistente gráfico, **describes** el
laboratorio en un archivo de texto y una herramienta lo construye. Ventajas:
se repite igual cada vez, se guarda en git, se comparte con un enlace y se
destruye y reconstruye en minutos si algo se rompe.

En este laboratorio hay tres capas:

| Capa | Herramienta | Qué hace | Dónde la verás |
| --- | --- | --- | --- |
| Imágenes base | Packer (lo ejecuta Ludus) | Construye las plantillas de Windows, Debian y Kali | `ludus templates build` |
| Topología | Ludus + YAML | Define VMs, redes, dominio | `rango/range-config-*.yml` |
| Servicios | Ansible | Instala Wazuh, nginx, MariaDB, agentes | `rango/ansible/roles/` |

## Proxmox y Ludus
**Proxmox VE** es el hipervisor: el programa que ejecuta las máquinas
virtuales. **Ludus** se instala encima y automatiza la creación de "rangos":
conjuntos aislados de VMs con su red, uno por alumno.

## Active Directory (AD)
Servicio de Windows que centraliza usuarios, equipos y permisos de una
organización. El **controlador de dominio** (DC01) guarda esa información; el
equipo cliente (WIN11-01) se "une al dominio" y los usuarios inician sesión con
cuentas del dominio `lab.local`. Cada inicio de sesión, correcto o fallido,
genera un evento en el registro de seguridad de Windows.

## SIEM y Wazuh
Un **SIEM** recoge los registros (logs) de muchos equipos en un único sitio,
los analiza con reglas y avisa cuando algo sospechoso ocurre. **Wazuh** es un
SIEM de código abierto con tres piezas, que aquí van en una sola VM:

| Pieza | Función |
| --- | --- |
| **Manager** | Recibe los eventos de los agentes, los descifra y aplica las reglas |
| **Indexer** | Almacena y permite buscar los eventos y las alertas |
| **Dashboard** | La interfaz web (`https://IP-del-SIEM`) |

Un **agente** es un programa pequeño instalado en cada equipo vigilado: lee sus
logs y se los envía al manager (puertos 1514 y 1515).

## Qué audita Wazuh sin que escribas reglas

| Módulo | Qué hace | Ejemplo en este laboratorio |
| --- | --- | --- |
| **FIM** (integridad de archivos) | Avisa si un archivo vigilado cambia | Modificar `/var/www/tienda/index.php` |
| **SCA** (evaluación de configuración) | Compara el sistema con una guía de seguridad y puntúa | Hallazgos de endurecimiento en `web` y `db` |
| **Vulnerabilidades** | Cruza el software instalado con vulnerabilidades conocidas | Paquetes desactualizados |
| **Eventos de seguridad** | Reglas sobre logs de autenticación, web, Windows | Inicios de sesión fallidos |
| **MITRE ATT&CK** | Etiqueta cada alerta con una técnica de ataque | Fuerza bruta → T1110 |

## Alerta y evento no son lo mismo
Un **evento** es una línea de log. Una **alerta** es un evento que una regla
consideró relevante. Un ataque puede generar eventos sin alerta si ninguna
regla lo reconoce: "no hay alerta" **no** significa "no pasó nada". Aprender a
distinguirlo es uno de los objetivos del itinerario avanzado.

## Modo de pruebas de Ludus
`ludus testing start` hace una instantánea de las VMs y **corta su salida a
Internet**, para que cualquier ataque se quede dentro del laboratorio.
`ludus testing stop` **restaura las VMs a esa instantánea**: lo que hayas
guardado dentro se pierde. El SIEM y la Kali (avanzado) están configurados para
**no** restaurarse y conservar alertas y notas.

## Vocabulario rápido

| Término | Significado |
| --- | --- |
| Rango (range) | Tu conjunto aislado de VMs |
| Plantilla (template) | Imagen base desde la que se clonan las VMs |
| Rol | Paquete de Ansible que instala y configura un servicio |
| VLAN | Red virtual separada; aquí la 10 (servicios) y la 20 (SOC) |
| WireGuard | VPN con la que tu equipo entra en tu rango |
