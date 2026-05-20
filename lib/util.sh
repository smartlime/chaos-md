#!/usr/bin/env bash
# Мелкие утилиты, используемые несколькими немезисами.

# Параллельно вызвать функцию для каждого хоста.
# Использование: parallel_for_hosts <fn> <hosts...> -- <args функции...>
#   fn вызывается как: fn <host> <args...>
# Если "--" не указан — fn вызывается без дополнительных аргументов.
parallel_for_hosts() {
    local fn="$1"; shift
    local hosts=() args=() seen_sep=0
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--" ]]; then seen_sep=1; shift; continue; fi
        if (( seen_sep )); then args+=("$1"); else hosts+=("$1"); fi
        shift
    done
    local pids=() host rc=0
    for host in "${hosts[@]}"; do
        # `${args[@]+"${args[@]}"}` безопасно подставляет пустой массив при set -u.
        "${fn}" "${host}" ${args[@]+"${args[@]}"} &
        pids+=($!)
    done
    local pid
    for pid in "${pids[@]}"; do
        wait "${pid}" || { rc=1; log "ПРЕДУПРЕЖДЕНИЕ: ${fn} (pid ${pid})"; }
    done
    return "${rc}"
}

# Имя файла для хранения UID (или иного «следа» хаоса) на управляющем хосте.
# Использование: state_file <host> [suffix]
#   logs/<TEST_NAME>.<host>.<suffix>
state_file() {
    local host="$1" suffix="${2:-uid}"
    echo "${LOG_DIR}/${TEST_NAME}.${host}.${suffix}"
}

# Перебрать UID-файлы текущего теста и для каждого вытащить host из имени.
# Использование: for_each_state_file <suffix> <fn>
#   fn вызывается как: fn <host> <state_file>
for_each_state_file() {
    local suffix="$1" fn="$2"
    local files=("${LOG_DIR}/${TEST_NAME}".*."${suffix}")
    [[ -f "${files[0]:-}" ]] || return 1
    local f base host
    for f in "${files[@]}"; do
        [[ -f "${f}" ]] || continue
        base="${f##*/}"
        base="${base#"${TEST_NAME}."}"
        host="${base%."${suffix}"}"
        "${fn}" "${host}" "${f}"
    done
    return 0
}
