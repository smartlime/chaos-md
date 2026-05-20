#!/usr/bin/env bash
# Деплой подпапки workload/ на target-хост (rsync → ~/${WL_REMOTE_DEST}).
# По умолчанию: $WL_REMOTE_HOST из env.local.sh — при пустом значении падаем.
#
# Стиль и опции — копия sync-to-remote.sh из корня проекта.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"

# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"

DRY_RUN=false
BACKGROUND=false
DELETE_REMOTE_EXTRA=false
WITH_LOCAL=false

usage() {
    cat <<EOF
Использование: $(basename "$0") [ОПЦИИ]

rsync подпапки workload/ на сервер.

  ${WL_REMOTE_USER}@${WL_REMOTE_HOST:-(WL_REMOTE_HOST не задан)}:~/${WL_REMOTE_DEST}/

Опции:
  -n, --dry-run       Только показать, что бы изменилось.
  --delete            Удалить на сервере файлы, которых нет локально (осторожно).
  --with-local        Включить env.local.sh (по умолчанию исключён).
  -b, --background    Запустить себя через nohup, вывести PID и выйти.
  -h, --help          Справка.

Переменные (задавать в workload/env.local.sh):
  WL_REMOTE_HOST   обязательно
  WL_REMOTE_USER   default = \${USER}
  WL_REMOTE_DEST   default = "ydb-workload"
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)    DRY_RUN=true; shift ;;
        --delete)        DELETE_REMOTE_EXTRA=true; shift ;;
        --with-local)    WITH_LOCAL=true; shift ;;
        -b|--background) BACKGROUND=true; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Неизвестный параметр: $1" >&2; usage >&2; exit 1 ;;
    esac
done

[[ -n "${WL_REMOTE_HOST:-}" ]] || die "WL_REMOTE_HOST не задан — заполните workload/env.local.sh (см. env.example.sh)"

REMOTE="${WL_REMOTE_USER}@${WL_REMOTE_HOST}:~/${WL_REMOTE_DEST}/"
LOG_FILE="${HOME}/sync-ydb-workload.$(date +%Y%m%d-%H%M%S).log"

if [[ "${BACKGROUND}" == true ]]; then
    _bg_args=()
    [[ "${DRY_RUN}" == true ]]             && _bg_args+=(--dry-run)
    [[ "${DELETE_REMOTE_EXTRA}" == true ]] && _bg_args+=(--delete)
    [[ "${WITH_LOCAL}" == true ]]          && _bg_args+=(--with-local)
    log_info "Фон: лог ${LOG_FILE}"
    nohup env WL_REMOTE_HOST="${WL_REMOTE_HOST}" WL_REMOTE_USER="${WL_REMOTE_USER}" WL_REMOTE_DEST="${WL_REMOTE_DEST}" \
        bash "${SELF_PATH}" "${_bg_args[@]}" >>"${LOG_FILE}" 2>&1 &
    log_info "PID $!"
    exit 0
fi

# Безопасные SSH-опции (без BatchMode, чтобы оператор мог ввести пароль/ключ при необходимости).
SSH_CMD="ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR"

RSYNC_ARGS=(
    -a
    -v
    -z
    --partial
    --progress
    --exclude '.*'
    --exclude 'logs/*'
    -e "${SSH_CMD}"
)

[[ "${WITH_LOCAL}" != true ]] && RSYNC_ARGS+=(--exclude 'env.local.sh')
[[ "${DRY_RUN}"  == true ]]   && RSYNC_ARGS+=(-n)
[[ "${DELETE_REMOTE_EXTRA}" == true ]] && RSYNC_ARGS+=(--delete)

log_info "rsync ${SCRIPT_DIR}/ → ${REMOTE}"
rsync "${RSYNC_ARGS[@]}" "${SCRIPT_DIR}/" "${REMOTE}"
log_info "готово"
