#!/usr/bin/env bash
# Genera rango/range-config-<itinerario>.local.yml sustituyendo los marcadores
# __CLAVE_*__ por claves aleatorias. El .local.yml está en .gitignore: es el que
# se carga en Ludus; el .yml original se queda sin secretos en el repositorio.
#
# Uso: scripts/preparar-config.sh basico|avanzado|lite
set -euo pipefail

itinerario="${1:-}"
case "$itinerario" in
  basico | avanzado | lite) ;;
  *) echo "Uso: $0 basico|avanzado|lite" >&2; exit 2 ;;
esac

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
origen="$raiz/rango/range-config-$itinerario.yml"
destino="$raiz/rango/range-config-$itinerario.local.yml"

[[ -f "$origen" ]] || { echo "No existe $origen" >&2; exit 1; }
command -v openssl > /dev/null || { echo "Hace falta openssl" >&2; exit 1; }

# Clave aleatoria que cumple la complejidad de Windows (mayúscula, minúscula, número y símbolo).
nueva_clave() {
  local base
  base="$(openssl rand -base64 24 | tr -d '/+=\n' | cut -c1-18)"
  printf '%sAa1!' "$base"
}

if [[ -f "$destino" ]]; then
  echo "Ya existe $destino: no lo sobrescribo (borra el archivo si quieres claves nuevas)." >&2
  exit 1
fi

cp "$origen" "$destino"
chmod 600 "$destino"
for marcador in CLAVE_ADMIN_DOMINIO CLAVE_USUARIO_DOMINIO CLAVE_DSRM CLAVE_BD_APP; do
  clave="$(nueva_clave)"
  # El carácter '!' es seguro con este delimitador; las claves no contienen '|'.
  sed -i "s|__${marcador}__|${clave}|g" "$destino"
done

if grep -q '__CLAVE_' "$destino"; then
  echo "Quedan marcadores sin sustituir en $destino" >&2
  exit 1
fi

echo "Creado: $destino (permisos 600)"
echo "Las claves del dominio están dentro de ese archivo: guárdalo, no lo subas a git."
echo "Siguiente paso: ludus range config set -f $destino"
