#!/usr/bin/env bash
# Rolling restart всех нод кластера: на каждой — stop tenant → storage → start storage → tenant.
# Не хаос-тест, а вспомогательная операция (CLUSTER_HOSTS из env.sh).

set -euo pipefail
TEST_NAME="rolling-restart"
TEST_DESC="Rolling restart всех нод кластера CLUSTER_HOSTS."
TEST_SCOPE="none"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/init.sh"
source "${SCRIPT_DIR}/nemesis/systemd.sh"

WAIT_BETWEEN="${DEFAULT_ROLLING_WAIT}"

chaos_usage_extra() {
    cat <<EOF
  -w, --wait SEC        Пауза между нодами (по умолчанию: ${DEFAULT_ROLLING_WAIT})
EOF
}
chaos_usage_examples() {
    cat <<EOF
  $(basename "$0")
  $(basename "$0") -w 60
  $(basename "$0") -C
EOF
}

chaos_parse_common "$@"
i=0; while (( i < ${#CHAOS_REMAINING_ARGS[@]} )); do
    case "${CHAOS_REMAINING_ARGS[i]}" in
        -w|--wait) WAIT_BETWEEN="${CHAOS_REMAINING_ARGS[i+1]}"; ((i+=2)) ;;
        *) echo "Неизвестный параметр: ${CHAOS_REMAINING_ARGS[i]}" >&2; chaos_usage >&2; exit 1 ;;
    esac
done

if [[ "${MODE_CHECK}" == true ]]; then
    nemesis_systemd_check "${CHECK_HOST}"
    exit 0
fi

chaos_log_script_start
trap 'chaos_log_script_end' EXIT

TOTAL="${#CLUSTER_HOSTS[@]}"
log "Кластер: ${TOTAL} нод; пауза между нодами: ${WAIT_BETWEEN}с"

FAILED=()
IDX=0
for host in "${CLUSTER_HOSTS[@]}"; do
    IDX=$(( IDX + 1 ))
    log_tl "CHAOS_START" "rolling restart  node=${IDX}/${TOTAL}  host=${host}"
    if nemesis_systemd_rolling_restart "${host}" "${IDX}" "${TOTAL}"; then
        log "  [OK] ${host}"
        log_tl "CHAOS_END  " "rolling restart  node=${IDX}/${TOTAL}  host=${host}"
    else
        log "  [FAIL] ${host} — продолжаем"
        log_tl "CHAOS_END  " "rolling restart  node=${IDX}/${TOTAL}  host=${host}  status=FAIL"
        FAILED+=("${host}")
    fi
    if (( WAIT_BETWEEN > 0 && IDX < TOTAL )); then
        log "  Пауза ${WAIT_BETWEEN}с"
        chaos_wait_with_timer "${WAIT_BETWEEN}" "next node ${IDX}/${TOTAL}"
    fi
done

if (( ${#FAILED[@]} > 0 )); then
    log "ПРЕДУПРЕЖДЕНИЕ: не перезапущены ноды: ${FAILED[*]}"
    exit 1
fi
log "Все ${TOTAL} нод перезапущены"
