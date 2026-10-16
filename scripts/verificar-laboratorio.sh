#!/usr/bin/env bash
# Comprueba el estado del laboratorio y da un informe OK / FALLO / NO VERIFICABLE.
#
# Se ejecuta desde una máquina que llegue al SIEM (la Kali del rango, o tu
# equipo con la VPN WireGuard del rango activa).
#
# Variables de entorno (las claves NO se pasan como argumento, para que no se
# vean en la lista de procesos):
#   SIEM_IP            IP de la VM del SIEM (obligatoria)
#   WAZUH_API_USER     usuario de la API de Wazuh (por defecto: wazuh)
#   WAZUH_API_PASS     clave de ese usuario (sin ella, las comprobaciones de la API
#                      salen como NO VERIFICABLE)
#   WEB_IP             IP del servidor web (opcional)
#
# Uso: scripts/verificar-laboratorio.sh [--itinerario basico|avanzado|lite] [--informe estado.md]
set -uo pipefail

itinerario="basico"
informe=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --itinerario) itinerario="${2:-}"; shift 2 ;;
    --informe) informe="${2:-}"; shift 2 ;;
    -h | --help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
case "$itinerario" in basico | avanzado | lite) ;; *) echo "--itinerario: basico|avanzado|lite" >&2; exit 2 ;; esac
: "${SIEM_IP:?Define SIEM_IP (IP de la VM del SIEM)}"
API_USER="${WAZUH_API_USER:-wazuh}"
API_PASS="${WAZUH_API_PASS:-}"
WEB_IP="${WEB_IP:-}"

# Agentes que deben aparecer activos. Los nombres son los hostnames del range-config.
# El perfil lite no incluye el cliente Windows 11.
if [[ "$itinerario" == "lite" ]]; then
  esperados=(DC01 web db)
else
  esperados=(DC01 web db WIN11-01)
fi

fallos=0
lineas=()

registrar() { # estado, comprobación, detalle
  local estado="$1" nombre="$2" detalle="${3:-}"
  [[ "$estado" == "FALLO" ]] && fallos=$((fallos + 1))
  printf '%-17s %-42s %s\n' "[$estado]" "$nombre" "$detalle"
  lineas+=("| $estado | $nombre | $detalle |")
}

puerto_abierto() { # host, puerto
  timeout 5 bash -c ">/dev/tcp/$1/$2" 2> /dev/null
}

# curl con credenciales por stdin (no aparecen en `ps`).
api() { # método, ruta, [token]
  if [[ -n "${3:-}" ]]; then
    curl -sk --max-time 15 -X "$1" -H "Authorization: Bearer $3" "https://$SIEM_IP:55000$2"
  else
    printf 'user = "%s:%s"\n' "$API_USER" "$API_PASS" |
      curl -sk --max-time 15 -K - -X "$1" "https://$SIEM_IP:55000$2"
  fi
}

echo "Laboratorio SIEM - estado ($(date '+%F %T')) - itinerario: $itinerario"
echo

# 1. Red hacia el SIEM -------------------------------------------------------
for par in "443:Dashboard de Wazuh" "55000:API de Wazuh" "1514:Eventos de agentes" "1515:Registro de agentes"; do
  p="${par%%:*}"; n="${par#*:}"
  if puerto_abierto "$SIEM_IP" "$p"; then
    registrar OK "SIEM $n (tcp/$p)" "responde"
  else
    registrar FALLO "SIEM $n (tcp/$p)" "sin respuesta en $SIEM_IP"
  fi
done

# 2. Servidor web ------------------------------------------------------------
if [[ -n "$WEB_IP" ]]; then
  codigo="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$WEB_IP/" || true)"
  if [[ "$codigo" == "200" ]]; then
    registrar OK "Servidor web (http)" "HTTP 200"
  else
    registrar FALLO "Servidor web (http)" "HTTP ${codigo:-sin respuesta}"
  fi
else
  registrar "NO VERIFICABLE" "Servidor web (http)" "define WEB_IP"
fi

# 3. API de Wazuh: agentes ---------------------------------------------------
if [[ -z "$API_PASS" ]]; then
  registrar "NO VERIFICABLE" "Agentes registrados y activos" "define WAZUH_API_PASS"
else
  token="$(api POST '/security/user/authenticate?raw=true' || true)"
  if [[ -z "$token" || "$token" == *'"error"'* || "$token" == *'"title"'* ]]; then
    registrar FALLO "Autenticación en la API de Wazuh" "usuario o clave no válidos, o API caída"
  else
    registrar OK "Autenticación en la API de Wazuh" "token obtenido"
    estados="$(api GET '/agents?select=name,status&limit=500' "$token" |
      python3 -c '
import json, sys
try:
    items = json.load(sys.stdin)["data"]["affected_items"]
except Exception:
    sys.exit(1)
for a in items:
    print(a.get("name", "?"), a.get("status", "?"))
' 2> /dev/null || true)"
    if [[ -z "$estados" ]]; then
      registrar FALLO "Lista de agentes" "la API no devolvió agentes"
    else
      for nombre in "${esperados[@]}"; do
        estado="$(awk -v n="$nombre" 'tolower($1) == tolower(n) {print $2}' <<< "$estados" | head -n1)"
        case "$estado" in
          active) registrar OK "Agente $nombre" "active" ;;
          "") registrar FALLO "Agente $nombre" "no está registrado" ;;
          *) registrar FALLO "Agente $nombre" "estado: $estado" ;;
        esac
      done
    fi
  fi
fi

# 4. CLI de Ludus (solo si está disponible) ----------------------------------
if command -v ludus > /dev/null 2>&1; then
  if ludus range status > /dev/null 2>&1; then
    registrar OK "Estado del rango (ludus range status)" "consultado"
  else
    registrar FALLO "Estado del rango (ludus range status)" "el comando falló"
  fi
else
  registrar "NO VERIFICABLE" "Estado del rango (ludus)" "CLI de ludus no disponible aquí"
fi

echo
if [[ "$fallos" -eq 0 ]]; then echo "RESULTADO: sin fallos."; else echo "RESULTADO: $fallos fallo(s)."; fi

if [[ -n "$informe" ]]; then
  {
    echo "# Informe de estado del laboratorio"
    echo
    echo "- Fecha: $(date '+%F %T')"
    echo "- Itinerario: $itinerario"
    echo "- SIEM: $SIEM_IP"
    echo
    echo "| Estado | Comprobación | Detalle |"
    echo "| --- | --- | --- |"
    printf '%s\n' "${lineas[@]}"
    echo
    echo "Fallos: $fallos"
  } > "$informe"
  echo "Informe guardado en $informe"
fi

[[ "$fallos" -eq 0 ]]
