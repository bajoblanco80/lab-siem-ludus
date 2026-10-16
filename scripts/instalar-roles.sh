#!/usr/bin/env bash
# Registra en el servidor Ludus los 4 roles de Ansible de este repositorio.
# Ejecútalo con el CLI de ludus ya autenticado (tu API key de usuario).
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v ludus > /dev/null || { echo "No encuentro el CLI 'ludus' en el PATH" >&2; exit 1; }

for rol in lab_wazuh_server lab_wazuh_agent lab_web lab_db; do
  echo "== Instalando rol $rol"
  ludus ansible roles add -d "$raiz/rango/ansible/roles/$rol" --force
done

echo
echo "Roles registrados:"
ludus ansible roles list | grep -E 'lab_(wazuh_server|wazuh_agent|web|db)' || {
  echo "No aparecen: revisa la salida anterior" >&2
  exit 1
}
