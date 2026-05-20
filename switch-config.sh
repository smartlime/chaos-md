#!/usr/bin/env bash
# Переключение активного env: env.sh → env-<имя>.sh (символическая ссылка).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Использование: $(basename "$0") <имя>

  Создаёт симлинк env.sh на файл env-<имя>.sh в каталоге репозитория.
  Если env-<имя>.sh нет — выход с ошибкой (ничего не меняется).

Примеры:
  $(basename "$0") prod        → env-prod.sh
  $(basename "$0") dev         → env-dev.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 1
fi

name="$1"
src="env-${name}.sh"
src_path="${SCRIPT_DIR}/${src}"
link_path="${SCRIPT_DIR}/env.sh"

if [[ ! -f "${src_path}" ]]; then
    echo "Ошибка: файл «${src}» не найден в ${SCRIPT_DIR}" >&2
    exit 1
fi

cd "${SCRIPT_DIR}"
ln -sfn "${src}" env.sh

echo "OK: env.sh → ${src}"
