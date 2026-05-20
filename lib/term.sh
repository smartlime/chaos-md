#!/usr/bin/env bash
# Терминал: цвета и обратный отсчёт ожидания.
# Цветной вывод и тикер включаются только если stderr — TTY (iTerm / xterm /
# Windows Terminal). При перенаправлении в файл цвета не пишутся, тикер
# превращается в обычный sleep.

if [[ -t 2 ]]; then
    C_HOST='\033[97m'        # яркий белый — управляющий хост / целевой ресурс
    C_REMOTE='\033[1;93m'    # ярко-жёлтый — что отправлено на удалённый хост
    C_CMD='\033[34m'         # синий — командная строка запуска
    C_TIMER='\033[36m'       # циан — тикер
    C_RESET='\033[0m'
else
    C_HOST='' C_REMOTE='' C_CMD='' C_TIMER='' C_RESET=''
fi

# Объект теста (один хост / список хостов / описание ДЦ).
chaos_term_target() {
    printf '%b%s%b\n' "${C_HOST}" "$*" "${C_RESET}" >&2
}

# Что выполняется на удалённом хосте — желтым, всегда на stderr.
# Подсветка призвана выделить удалённую активность среди обычного логирования.
chaos_term_remote_cmd() {
    printf '%b→  %s%b\n' "${C_REMOTE}" "$*" "${C_RESET}" >&2
}

# Полная командная строка запуска самого теста (для воспроизводимости).
chaos_term_cmdline() {
    [[ $# -lt 1 ]] && return 0
    printf '%b' "${C_CMD}" >&2
    printf '%q' "$1" >&2; shift
    local a; for a in "$@"; do printf ' %q' "${a}" >&2; done
    printf '%b\n' "${C_RESET}" >&2
}

# Форматирование секунд → MM:SS или HH:MM:SS.
chaos_fmt_hms() {
    local s="$1"
    if (( s >= 3600 )); then
        printf '%d:%02d:%02d' $(( s / 3600 )) $(( (s % 3600) / 60 )) $(( s % 60 ))
    else
        printf '%02d:%02d' $(( s / 60 )) $(( s % 60 ))
    fi
}

# Ожидание с обратным отсчётом в терминале.
# При TTY — обновляет одну строку через \r и ANSI «erase line»;
# при перенаправлении — обычный sleep без шума в логах.
# Использование: chaos_wait_with_timer <seconds> [подпись]
chaos_wait_with_timer() {
    local total="$1"; shift
    local hint="${*:-}"

    if [[ ! -t 2 ]] || (( total <= 0 )); then
        sleep "${total}"
        return
    fi

    local total_s; total_s="$(chaos_fmt_hms "${total}")"
    local start now elapsed remaining end
    start=$(date +%s)
    end=$(( start + total ))

    while :; do
        now=$(date +%s)
        (( now >= end )) && break
        elapsed=$(( now - start ))
        remaining=$(( total - elapsed ))
        printf '\r\033[2K%b⏱  %s / %s   осталось %s%s%b' \
            "${C_TIMER}" \
            "$(chaos_fmt_hms "${elapsed}")" \
            "${total_s}" \
            "$(chaos_fmt_hms "${remaining}")" \
            "${hint:+   ${hint}}" \
            "${C_RESET}" >&2
        sleep 1
    done
    # Очищаем строку с тикером — следующая запись начинается с чистой строки.
    printf '\r\033[2K' >&2
}
