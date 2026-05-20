#!/usr/bin/env bash
# Сборка команд ydb CLI и валидация конфигурации YDB.

# Проверить, что задан хотя бы один способ подключения.
ydb_require_target() {
    if [[ -z "${WL_YDB_PROFILE:-}" ]]; then
        [[ -n "${WL_YDB_ENDPOINT:-}" ]] || die "WL_YDB_ENDPOINT не задан (или задайте WL_YDB_PROFILE) — заполните workload/env.local.sh (см. env.example.sh)"
        [[ -n "${WL_YDB_DATABASE:-}" ]] || die "WL_YDB_DATABASE не задан — заполните workload/env.local.sh (см. env.example.sh)"
    fi
}

# Печать массива ydb-аргументов подключения (профиль ИЛИ endpoint+database).
# Использование:  ydb_args=(); while IFS= read -r a; do ydb_args+=("$a"); done < <(ydb_conn_args)
ydb_conn_args() {
    if [[ -n "${WL_YDB_PROFILE:-}" ]]; then
        printf -- '-p\n%s\n' "${WL_YDB_PROFILE}"
    else
        printf -- '-e\n%s\n-d\n%s\n' "${WL_YDB_ENDPOINT}" "${WL_YDB_DATABASE}"
    fi
}

# Запуск ydb с подключением и переданными аргументами.
# Уважает WL_DRY_RUN: если true — печатает команду и не выполняет.
ydb_run() {
    local conn=()
    while IFS= read -r a; do conn+=("$a"); done < <(ydb_conn_args)
    if [[ "${WL_DRY_RUN:-false}" == "true" ]]; then
        printf '%s' "$ ${WL_YDB_BIN}"
        printf ' %q' "${conn[@]}" "$@"
        printf '\n'
        return 0
    fi
    "${WL_YDB_BIN}" "${conn[@]}" "$@"
}
