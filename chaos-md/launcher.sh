#!/usr/bin/env bash
# dist/chaos-md — лаунчер для распакованного дистрибутива.
# Бинарники и скрипты лежат рядом; --root указывает на этот каталог.

set -e
DIST_DIR="$(cd "$(dirname "$0")" && pwd)"

arch="$(uname -m)"
case "${arch}" in
    x86_64|amd64)  exe="${DIST_DIR}/chaos-md.x86_64" ;;
    aarch64|arm64) exe="${DIST_DIR}/chaos-md.aarch64" ;;
    *)
        echo "Архитектура ${arch} не поддерживается Chaos MD" >&2
        exit 1
        ;;
esac

if [[ ! -f "${exe}" ]]; then
    echo "Нет бинарника: ${exe}" >&2
    exit 1
fi

exec "${exe}" --root "${DIST_DIR}" "$@"
