#!/usr/bin/env bash
# Полный последовательный прогон хаос-тестов.
#
# Тайминги (env override):
#   TIME_TEST       длительность одной фазы -t (default 1200)
#   TIME_WAIT       пауза перед -D (default 600)
#   TIME_WAIT_NEXT  пауза между тестами (default = TIME_TEST)
#
# Тест 03 (отказ диска):
#   DISK_DEVICE     блочное устройство (default из env.sh: DEFAULT_DISK_DEVICE → vdb)
#   SKIP_DISK=1     пропустить тест 03 (если диск недоступен или не нужен)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

TIME_TEST="${TIME_TEST:-1200}"
TIME_WAIT="${TIME_WAIT:-600}"
TIME_WAIT_NEXT="${TIME_WAIT_NEXT:-$TIME_TEST}"
TIME=( -t "${TIME_TEST}" )
BLADE_TO=( -T "${TIME_TEST}" )
SKIP_DISK="${SKIP_DISK:-0}"

# Таймер ожидания, переиспользуем lib/term.sh.
# shellcheck source=lib/term.sh
source "${SCRIPT_DIR}/lib/term.sh"

_wait_destroy() {
    chaos_wait_with_timer "${TIME_WAIT}" "пауза перед -D"
}

_wait_next() {
    chaos_wait_with_timer "${TIME_WAIT_NEXT}" "пауза перед следующим тестом"
    printf '%s\n' "************************************************************************"
}

echo "run-all: TIME_TEST=${TIME_TEST} TIME_WAIT=${TIME_WAIT} TIME_WAIT_NEXT=${TIME_WAIT_NEXT}"

# 01 CPU
./01-cpu-load.sh -1 "${TIME[@]}" "${BLADE_TO[@]}"
./01-cpu-load.sh -4 "${TIME[@]}" "${BLADE_TO[@]}"
_wait_destroy
./01-cpu-load.sh -D
_wait_next

# 02 mem
./02-mem-load.sh -1 "${TIME[@]}" "${BLADE_TO[@]}"
./02-mem-load.sh -4 "${TIME[@]}" "${BLADE_TO[@]}"
_wait_destroy
./02-mem-load.sh -D
_wait_next

# 03 disk — включён в прогон, при необходимости SKIP_DISK=1
if [[ "${SKIP_DISK}" == "0" ]]; then
    _disk_args=()
    [[ -n "${DISK_DEVICE:-}" ]] && _disk_args+=(-d "${DISK_DEVICE}")
    ./03-disk-fail.sh -1 "${TIME[@]}" "${_disk_args[@]}"
    _wait_next
else
    echo "run-all: пропуск 03 (SKIP_DISK=1)" >&2
fi

# 04 delay
./04-net-delay.sh -1 "${TIME[@]}"
./04-net-delay.sh -4 "${TIME[@]}"
_wait_destroy
./04-net-delay.sh -D
_wait_next

# 05 loss
./05-net-loss.sh -1 "${TIME[@]}"
./05-net-loss.sh -4 "${TIME[@]}"
_wait_destroy
./05-net-loss.sh -D
_wait_next

# 06 drop (только нода)
./06-net-drop.sh -1 "${TIME[@]}"
_wait_destroy
./06-net-drop.sh -D
_wait_next

# 07 bw
./07-net-bw.sh -1 "${TIME[@]}"
./07-net-bw.sh -4 "${TIME[@]}"
_wait_destroy
./07-net-bw.sh -D
_wait_next

# 08 freeze
./08-proc-freeze.sh -1 "${TIME[@]}"
_wait_next

# 09 kill (с явным рестартом storage после паузы)
./09-proc-kill.sh -1 "${TIME[@]}" -r
_wait_next

# 10 rolling upgrade — нужен архив в dist/ или ROLLING_UPGRADE_DIST
_roll_dist=""
if [[ -n "${ROLLING_UPGRADE_DIST:-}" && -f "${ROLLING_UPGRADE_DIST}" ]]; then
    _roll_dist="${ROLLING_UPGRADE_DIST}"
elif compgen -G "${SCRIPT_DIR}/dist/"*.tar.xz >/dev/null 2>&1; then
    _roll_dist="$(compgen -G "${SCRIPT_DIR}/dist/"*.tar.xz | head -1)"
fi
if [[ -n "${_roll_dist}" ]]; then
    ./10-rolling-upgrade.sh -1 "${TIME[@]}" -f "${_roll_dist}"
else
    echo "run-all: пропуск 10 (нет архива в dist/*.tar.xz и не задан ROLLING_UPGRADE_DIST)" >&2
fi
_wait_next

# 11 dc drop
./11-dc-drop.sh -4 "${TIME[@]}"
_wait_destroy
./11-dc-drop.sh -D
_wait_next

# 12 server stop
./12-server-stop.sh -1 "${TIME[@]}"
_wait_destroy
./12-server-stop.sh -D

echo "run-all: завершено"
