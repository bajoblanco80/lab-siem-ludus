# 06 · Perfil lite: el laboratorio básico en 16 GB de RAM

Para quien solo dispone de **un equipo dedicado de 16 GB**. Mantiene lo esencial
(SIEM, Active Directory, servidor web y base de datos) y quita lo que no cabe.

> **Fuera de lo soportado por Ludus.** Ludus documenta 32 GB de RAM como mínimo
> para un rango. Este perfil lo reduce por debajo de ese mínimo. Funciona **si
> las cifras de abajo se confirman en tu equipo** (ver
> [VERIFICACION-PENDIENTE.md](../VERIFICACION-PENDIENTE.md), sección G) y no es
> adecuado para un servidor de clase con varios alumnos.

## Qué incluye y qué no

| | Básico | **Lite** |
| --- | --- | --- |
| SIEM (Wazuh) | ✅ 8 GB | ✅ **6 GB** |
| `DC01` (Active Directory) | ✅ 4 GB | ✅ **3 GB** |
| Servidor web `web` | ✅ 2 GB | ✅ **1 GB** |
| Base de datos `db` | ✅ 2 GB | ✅ **1 GB** |
| Cliente `WIN11-01` | ✅ 4 GB | ❌ |
| Router de Ludus | por defecto | **1 GB** (fijado) |
| **Total de VMs** | ≈ 20 GB | **≈ 12 GB** |
| Agentes que reportan | 4 | **3** |
| Itinerario avanzado (Kali) | sí | **no** (la Kali añade 4 GB y no cabe) |

Con Proxmox o Debian ocupando ~2 GB, el conjunto llega a ≈ 14 GB: queda poco margen.

## Requisitos del equipo
- **Dedicado y directamente sobre el hardware** (Debian 12/13 o Proxmox 8/9).
  **No sirve** una máquina virtual dentro de un Mac ni de otro equipo: el sistema
  anfitrión necesita su propia RAM y no quedaría para el laboratorio.
- x86_64 con virtualización (`vmx` o `svm`), 4 núcleos o más, SSD.
- 16 GB de RAM y, recomendable, 4 GB de *swap* como colchón.
- Por cable, y sin Docker en el host (requisitos generales de Ludus).

## Cómo se usa
Igual que el itinerario básico, cambiando el perfil:

```bash
scripts/instalar-roles.sh
scripts/preparar-config.sh lite
ludus range config set -f rango/range-config-lite.local.yml
ludus range deploy
ludus range logs -f

# Comprobación de estado: 3 agentes (DC01, web, db)
scripts/verificar-laboratorio.sh --itinerario lite --informe estado.md
```
Sigue la [práctica básica](../itinerario-basico/practica.md) con los cambios que
indica en su apartado «Perfil lite».

## Qué vigilar
| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| El SIEM se reinicia o el dashboard no responde | Falta de RAM para el indexer (6 GB es el límite) | Sube `siem` a 7–8 GB en el YAML y baja `DC01` a 2–3 GB |
| El host usa *swap* constantemente | Sobrecarga de memoria | Apaga lo que no uses; cierra sesiones gráficas del host |
| `DC01` va muy lento | 3 GB es justo para Windows Server con escritorio | Sube a 4 GB si te sobra RAM |
| Un despliegue falla a media ejecución | Las VMs arrancan a la vez y se agota la RAM | Reintenta `ludus range deploy`; no abras nada más en el equipo |

Para medir de verdad, en el host: `free -h`, y en Proxmox la pestaña *Summary* de
cada VM. Ajusta los valores de `range-config-lite.yml` con lo que veas.

## Otras palancas (no incluidas, sin probar)
- **Modo *ballooning***: el esquema de Ludus admite `ram_min_gb` en cada VM para
  que Proxmox recupere RAM no usada. No se ha activado porque el comportamiento de
  Wazuh y de las plantillas de Windows con *ballooning* no se ha comprobado.
- **Sin Active Directory**: quitar `DC01` ahorra otros 3 GB, pero se pierden el
  dominio y los eventos de Windows; no es un cambio trivial y no lo cubre este perfil.
