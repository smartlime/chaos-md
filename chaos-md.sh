#!/usr/bin/env bash
# Запуск TUI-диспетчера Chaos MD из корня репозитория.
# macOS: нативный бинарник из dist/ (cargo build --release).
# Linux: статический musl-бинарник из dist/ (make orch, нужен Docker).
#
# Опции:
#   -d, --dev    Запустить через 'cargo run --release' (режим разработки)
#   Остальные аргументы передаются в chaos-md.

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"
DEV_MODE=0

if [[ -f "${REPO_ROOT}/env.sh" ]]; then
    source "${REPO_ROOT}/env.sh"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dev)
            DEV_MODE=1
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [[ ${DEV_MODE} -eq 1 ]]; then
    cd "${REPO_ROOT}/chaos-md"
    exec cargo run --release -- --root "${REPO_ROOT}" "$@"
fi

arch="$(uname -m)"

if [[ "${OS}" == "Darwin" ]]; then
    exe="${REPO_ROOT}/dist/chaos-md.darwin_${arch}"
    if [[ ! -f "${exe}" ]]; then
        echo "Нет бинарника: ${exe}" >&2
        echo "Соберите: make orch   (или: cd chaos-md && cargo build --release)" >&2
        exit 1
    fi
else
    case "${arch}" in
        x86_64|amd64)  exe="${REPO_ROOT}/dist/chaos-md.x86_64" ;;
        aarch64|arm64) exe="${REPO_ROOT}/dist/chaos-md.aarch64" ;;
        *)
            echo "Архитектура ${arch} не поддерживается Chaos MD" >&2
            exit 1
            ;;
    esac
fi

if [[ ! -f "${exe}" ]]; then
    echo "Нет бинарника: ${exe}" >&2
    echo "Соберите: make orch  (нужен Docker)" >&2
    exit 1
fi

exec "${exe}" --root "${REPO_ROOT}" "$@"
