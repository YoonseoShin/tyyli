#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
RN_DIR="${PROJECT_DIR}/.jac/mobile-rn"
API_PORT="${JAC_API_PORT:-8000}"
METRO_PORT="${JAC_RN_METRO_PORT:-8081}"
OS_NAME="$(uname -s)"
IS_WSL=false

if [[ "${OS_NAME}" == "Linux" ]] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  IS_WSL=true
fi

detect_lan_host() {
  case "${OS_NAME}" in
    Darwin)
      ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
      ;;
    Linux)
      if [[ "${IS_WSL}" == true ]] && command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -NonInteractive -Command \
          '$route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1; (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex | Where-Object { $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1 -ExpandProperty IPAddress)' \
          2>/dev/null | tr -d '\r' | head -n 1
      else
        ip -4 route get 1.1.1.1 2>/dev/null | awk '
          { for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }
        '
      fi
      ;;
    *)
      return 0
      ;;
  esac
}

if [[ -n "${JAC_RN_DEV_HOST:-}" ]]; then
  LAN_HOST="${JAC_RN_DEV_HOST}"
else
  LAN_HOST="$(detect_lan_host)"
fi

if [[ -z "${LAN_HOST}" ]]; then
  echo "Could not determine the LAN address Expo Go should use."
  echo "Set it explicitly and retry: JAC_RN_DEV_HOST=your-computer-lan-ip ./scripts/dev_mobile.sh"
  exit 1
fi

if [[ "${IS_WSL}" == true ]]; then
  echo "WSL detected. The Expo Go address below must be reachable from your phone."
  echo "For WSL2, enable mirrored networking in %UserProfile%\\.wslconfig and allow"
  printf 'inbound TCP ports %s and %s through the Hyper-V firewall, or configure Windows port forwarding.\n' \
    "${API_PORT}" "${METRO_PORT}"
  echo "Restart WSL after changing its networking mode."
fi

if [[ ! -d "${RN_DIR}" ]]; then
  echo "Expo project not found at ${RN_DIR}. Run 'jac setup' first."
  exit 1
fi

if lsof -nP -iTCP:"${API_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port ${API_PORT} is already in use. Stop the existing API server first."
  lsof -nP -iTCP:"${API_PORT}" -sTCP:LISTEN
  exit 1
fi

if lsof -nP -iTCP:"${METRO_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port ${METRO_PORT} is already in use. Stop the existing Metro server first."
  lsof -nP -iTCP:"${METRO_PORT}" -sTCP:LISTEN
  exit 1
fi

API_URL="http://${LAN_HOST}:${API_PORT}"

echo "Compiling the latest Jac mobile code..."
cd "${PROJECT_DIR}"
# The prepared-application cache goes stale when server-side modules change and
# then fails the client compile with "runtime import(s) ... are not exported".
# Clearing it costs a few seconds and avoids that.
jac clean --cache --force >/dev/null 2>&1 || true
jac run --no-takeover scripts/compile_mobile.jac
jac run --no-takeover scripts/ensure_expo_sdk_58.jac
"${SCRIPT_DIR}/check_mobile_js.sh"

printf 'globalThis.__JAC_API_BASE_URL__ = "%s";\n' "${API_URL}" > "${RN_DIR}/__jacApiBase.js"

jac run --no-takeover --serve --no-client --port "${API_PORT}" ai_server.jac &
API_PID=$!

cleanup() {
  if kill -0 "${API_PID}" >/dev/null 2>&1; then
    kill "${API_PID}" >/dev/null 2>&1 || true
    wait "${API_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

# The API server compiles its modules on start; ~30-60 s inside Docker on an
# Intel Mac, so allow up to 3 minutes before giving up.
SERVER_READY=false
echo "Waiting for the Jac API server on port ${API_PORT}..."
for ((i = 1; i <= 360; i++)); do
  if curl -fsS "http://127.0.0.1:${API_PORT}/openapi.json" >/dev/null 2>&1; then
    SERVER_READY=true
    break
  fi
  if ! kill -0 "${API_PID}" >/dev/null 2>&1; then
    echo "The Jac API server exited before becoming ready (see the output above)."
    exit 1
  fi
  if (( i % 20 == 0 )); then
    echo "  still starting ($(( i / 2 )) s)..."
  fi
  sleep 0.5
done

if [[ "${SERVER_READY}" != "true" ]]; then
  echo "Jac API server did not become ready."
  exit 1
fi

echo ""
echo "Tyyli development servers are ready:"
echo "  Expo Go: exp://${LAN_HOST}:${METRO_PORT}"
echo "  API:     ${API_URL}"
echo ""

cd "${PROJECT_DIR}"
JAC_RN_METRO_PORT="${METRO_PORT}" \
  REACT_NATIVE_PACKAGER_HOSTNAME="${LAN_HOST}" \
  jac run --no-takeover scripts/start_metro.jac
