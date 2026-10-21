#!/bin/zsh
# Run the Tyyli mobile dev servers (Jac API + Expo Metro) inside a Jac 0.37.x
# Docker container. For machines that cannot install Jac 0.37.x natively
# (e.g. Intel Macs). Phone + Mac must be on the same Wi-Fi.
#
#   ./scripts/docker_dev.sh            # start API (8000) + Metro (8081)
#   ./scripts/docker_dev.sh setup      # (re)install mobile dependencies
#   ./scripts/docker_dev.sh shell      # bash inside the container
#   ./scripts/docker_dev.sh build      # (re)build the image
#
# One-time: run `npx expo login` on the Mac and sign in to Expo Go on the phone
# with the same account (Expo Go on iOS requires this).
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
IMAGE="tyyli-jac-dev:0.37.25"
NAME="tyyli-dev"
API_PORT="${JAC_API_PORT:-8000}"
METRO_PORT="${JAC_RN_METRO_PORT:-8081}"
LAN_HOST="${JAC_RN_DEV_HOST:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)}"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop and try again."
  exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1 || [[ "${1:-}" == "build" ]]; then
  echo "Building ${IMAGE}..."
  docker build -t "${IMAGE}" -f "${PROJECT_DIR}/docker/Dockerfile.dev" "${PROJECT_DIR}/docker"
  [[ "${1:-}" == "build" ]] && exit 0
fi

# Named volumes keep the container's Jac state and node_modules off the Mac
# filesystem (fast installs, no clash with a host Jac of a different version).
for vol in tyyli-jac-state tyyli-opt-jac-cache; do
  if ! docker volume inspect "${vol}" >/dev/null 2>&1; then
    docker volume create "${vol}" >/dev/null
    docker run --rm -u 0 -v "${vol}:/vol" --entrypoint chown "${IMAGE}" -R 1000:1000 /vol
  fi
done

if [[ -z "${LAN_HOST}" && "${1:-}" != "setup" && "${1:-}" != "shell" ]]; then
  echo "Could not find the Mac's LAN IP. Run: JAC_RN_DEV_HOST=192.168.x.x $0"
  exit 1
fi

TTY_FLAGS=(-i)
[[ -t 0 ]] && TTY_FLAGS=(-it)

docker rm -f "${NAME}" >/dev/null 2>&1 || true

COMMON=(
  --name "${NAME}" --rm "${TTY_FLAGS[@]}"
  -p "${API_PORT}:${API_PORT}" -p "${METRO_PORT}:${METRO_PORT}"
  -e JAC_RN_DEV_HOST="${LAN_HOST}"
  -e REACT_NATIVE_PACKAGER_HOSTNAME="${LAN_HOST}"
  -e JAC_API_PORT="${API_PORT}" -e JAC_RN_METRO_PORT="${METRO_PORT}"
  -e EXPO_NO_TELEMETRY=1
  # Expo Go on iOS requires the CLI and the phone to be signed in to the same
  # Expo account. Share the Mac's Expo login (npx expo login) with the container,
  # or set EXPO_TOKEN (expo.dev access token) for a non-interactive login.
  -v "${HOME}/.expo:/home/jac/.expo"
  -e EXPO_TOKEN="${EXPO_TOKEN:-}"
  -v "${PROJECT_DIR}:/app"
  -v tyyli-jac-state:/app/.jac
  -v tyyli-opt-jac-cache:/opt/jac/cache
  "${IMAGE}"
)

case "${1:-}" in
  setup) exec docker run "${COMMON[@]}" -c 'cd /app && jac setup' ;;
  shell) exec docker run "${COMMON[@]}" ;;
  *)     exec docker run "${COMMON[@]}" -c 'cd /app && ./scripts/dev_mobile.sh' ;;
esac
