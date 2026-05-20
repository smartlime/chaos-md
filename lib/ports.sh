#!/usr/bin/env bash
# Разбор YDB_PORTS в массив CHAOS_YDB_PORTS_ARR.
# Поддерживаются: отдельные порты (через запятую) и диапазоны вида
#   31000:32000  /  31000-32000  (включительно).

chaos_ydb_ports_to_array() {
    CHAOS_YDB_PORTS_ARR=()
    local _token _a _b _i _t _tmp
    IFS=',' read -ra _tmp <<< "${YDB_PORTS}"
    for _token in "${_tmp[@]}"; do
        _token="${_token//[[:space:]]/}"
        [[ -z "${_token}" ]] && continue
        if [[ "${_token}" =~ ^([0-9]+)[-:]([0-9]+)$ ]]; then
            _a="${BASH_REMATCH[1]}"; _b="${BASH_REMATCH[2]}"
            if (( _a > _b )); then _t=${_a}; _a=${_b}; _b=${_t}; fi
            if (( _b - _a > 20000 )); then
                echo "chaos_ydb_ports_to_array: диапазон ${_a}-${_b} слишком широк (макс. 20000)" >&2
                return 1
            fi
            for ((_i = _a; _i <= _b; _i++)); do
                CHAOS_YDB_PORTS_ARR+=("${_i}")
            done
        else
            CHAOS_YDB_PORTS_ARR+=("${_token}")
        fi
    done
}

# Краткая строка для help (берётся прямо из env, без раскрытия диапазона).
chaos_ydb_ports_help_line() {
    echo "${YDB_PORTS}"
}

# Список ydbd-юнитов из env для help (тест 12).
chaos_ydbd_units_help() {
    echo "  ${YDBD_STORAGE_SERVICE}"
    local _u
    for _u in "${YDBD_TENANT_SERVICES[@]}"; do
        echo "  ${_u}"
    done
}
