#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
RN_DIR="${PROJECT_DIR}/.jac/mobile-rn"
API_PORT="${JAC_API_PORT:-8000}"
METRO_PORT="${JAC_RN_METRO_PORT:-8081}"
LAN_HOST="${JAC_RN_DEV_HOST:-$(ipconfig getifaddr en0 2>/dev/null || true)}"

if [[ -z "${LAN_HOST}" ]]; then
  LAN_HOST="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

if [[ -z "${LAN_HOST}" ]]; then
  echo "Could not find the Mac's LAN IP address."
  echo "Run again with: JAC_RN_DEV_HOST=192.168.x.x ./scripts/dev_mobile.sh"
  exit 1
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
jac run --no-takeover scripts/compile_mobile.jac

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

SERVER_READY=false
for _ in {1..40}; do
  if curl -fsS "http://127.0.0.1:${API_PORT}/openapi.json" >/dev/null 2>&1; then
    SERVER_READY=true
    break
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

cd "${RN_DIR}"
./node_modules/.bin/expo start --port "${METRO_PORT}" --clear --lan
