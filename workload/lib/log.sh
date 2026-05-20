#!/usr/bin/env bash
# Логирование для модуля нагрузки (стиль идентичен корневому lib/log.sh).
# Все сообщения уходят в stdout; если задан WL_LOG_FILE — ещё и в файл.

_wl_now() {
    TZ="${WL_LOG_TZ:-Europe/Moscow}" date '+%Y-%m-%d %H:%M:%S %Z'
}

_wl_emit() {
    local level="$1"; shift
    local msg="[$(_wl_now)] [${level}] $*"
    printf '%s\n' "${msg}"
    if [[ -n "${WL_LOG_FILE:-}" ]]; then
        printf '%s\n' "${msg}" >> "${WL_LOG_FILE}"
    fi
}

log_info()  { _wl_emit INFO  "$*"; }
log_warn()  { _wl_emit WARN  "$*" >&2; }
log_err()   { _wl_emit ERROR "$*" >&2; }
log_section() { log_info "=== $* ==="; }

die() {
    log_err "$*"
    exit "${2:-2}"
}
