# 05 · Uso responsable

Este laboratorio contiene material que **solo** es seguro dentro del rango
aislado:

- Una aplicación web con **inyección SQL a propósito** (`rango/ansible/roles/lab_web/templates/*.php.j2`).
- Datos de usuarios **ficticios** con claves en claro, para practicar su detección.
- En el itinerario avanzado, una máquina atacante (Kali).

## Reglas

1. **Solo dentro de tu rango.** Ataca únicamente las VMs de tu propio rango.
   Nunca redes del centro, de otros alumnos o de Internet.
2. **Modo de pruebas siempre.** Antes de cualquier ataque: `ludus testing start`.
   Bloquea la salida a Internet de las VMs atacadas y de la Kali.
3. **No publiques la aplicación.** No la expongas a Internet ni la copies a un
   servidor real. No contiene datos reales y no debe tenerlos nunca.
4. **No reutilices claves.** Las claves del laboratorio se generan aleatorias
   y viven en un archivo `.local.yml` que git ignora. No las uses en otros sitios.
5. **No subas secretos al repositorio:** perfiles WireGuard (`*.conf`), claves
   de Ludus, `wazuh-passwords.txt`, los `.local.yml`. El `.gitignore` ayuda, pero
   revisa tu `git status` antes de cada `git push`.
6. **Informa si algo se escapa.** Si ves tráfico del laboratorio saliendo de tu
   rango, apágalo y avisa al docente.

## Para quien publique su fork
Mantén este aviso en el README, no incluyas capturas con claves ni IP reales de
tu centro y no añadas ataques contra servicios fuera del rango.
