#!/usr/bin/env bash
# Немезис: Linux Traffic Control (tc).
# Используется в тестах 04 (delay), 05 (loss), 07 (bandwidth).
#
# У каждого интерфейса свой root prio + фильтры; смешивать protocol ip с match ip6 нельзя —
# иначе ядро может вернуть ошибки вида «Filter with specified priority/protocol not found» при несогласованном del/show.

# Интерфейсы: NET_IFACES и опционально NET_IFACES_TABLE (см. lib/net.sh).
#
# Базовый API:
#   nemesis_tc_netem_apply <host> <netem_args> <timeout>
#   nemesis_tc_tbf_apply   <host> <rate_mbit> <burst> <timeout>
#   nemesis_tc_teardown    <host>
#   nemesis_tc_check       <host>

# --- netem (04/05): root prio, netem на 1:1, «пустой» netem на 1:2 ---
#
# Prio 2 (выше приоритет, чем 3): для каждого порта из YDB_PORTS — и sport, и dport (IPv4/IPv6
# отдельно). Иначе исходящие к соседям с эфемерным sport не попадают в netem (dport = порт YDB).
#
# Prio 3: passthrough → class 1:2. IPv4: catch-all по src. IPv6: 17 u32-масок по sport
# (проверенная схема — u32 не матчит sport по фикс. смещению из-за extension headers;
# match ip6 sport/dport на prio 2 ядро парсит само).

_nemesis_tc_emit_ipv4_passthrough_prio3() {
    local iface="$1"
    printf '%s\n' "sudo tc filter add dev ${iface} protocol ip parent 1:0 prio 3 u32 match ip src 0.0.0.0/0 flowid 1:2"
}

_nemesis_tc_emit_ipv6_passthrough_prio3() {
    local iface="$1"
    # Покрывают весь диапазон sport 0..65535 → flowid 1:2 (passthrough).
    # YDB-порты перехватываются фильтрами prio 2 раньше.
    cat <<EOF
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x0    0xffff flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x1    0xffff flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x2    0xfffe flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x4    0xfffc flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x8    0xfff8 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x10   0xfff0 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x20   0xffe0 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x40   0xffc0 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x80   0xff80 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x100  0xff00 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x200  0xfe00 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x400  0xfc00 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x800  0xf800 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x1000 0xf000 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x2000 0xe000 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x4000 0xc000 flowid 1:2
sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 3 u32 match ip6 sport 0x8000 0x8000 flowid 1:2
EOF
}

_nemesis_tc_netem_remote_script() {
    local netem_params="$1" timeout_s="$2"
    local iface lines ipv4_on ipv6_on
    ipv4_on=false
    ipv6_on=false
    chaos_net_ipv4_enabled && ipv4_on=true
    chaos_net_ipv6_enabled && ipv6_on=true

    local rb=""
    rb+="set -euo pipefail"$'\n'
    rb+="# Снять предыдущий таймер и root qdisc на всех целевых интерфейсах"$'\n'
    rb+="if [[ -f /tmp/tc-chaos.pid ]]; then"$'\n'
    rb+="  kill \"\$(cat /tmp/tc-chaos.pid)\" 2>/dev/null || true"$'\n'
    rb+="  rm -f /tmp/tc-chaos.pid"$'\n'
    rb+="fi"$'\n'

    rb+="rm -f /tmp/tc-chaos-ifaces.list"$'\n'
    for iface in "${CHAOS_NET_IFACES_ARR[@]}"; do
        rb+="sudo tc qdisc del dev ${iface} root 2>/dev/null || true"$'\n'
        rb+="printf '%s\\n' '${iface}' >> /tmp/tc-chaos-ifaces.list"$'\n'
    done

    for iface in "${CHAOS_NET_IFACES_ARR[@]}"; do
        rb+=""$'\n'
        rb+="echo '--- tc-chaos dev=${iface} ---'"$'\n'
        rb+="sudo tc qdisc add dev ${iface} root handle 1: prio"$'\n'
        rb+="sudo tc qdisc add dev ${iface} parent 1:1 handle 10: netem ${netem_params} limit 262144"$'\n'

        if [[ "${ipv4_on}" == true ]]; then
            rb+="# IPv4: passthrough (prio 3) → class 1:2"$'\n'
            local line
            while IFS= read -r line || [[ -n "${line}" ]]; do
                [[ -n "${line}" ]] && rb+="${line}"$'\n'
            done < <(_nemesis_tc_emit_ipv4_passthrough_prio3 "${iface}")
            rb+="# IPv4: YDB sport/dport (prio 2) → class 1:1 (netem)"$'\n'
            for p in "${CHAOS_YDB_PORTS_ARR[@]}"; do
                rb+="sudo tc filter add dev ${iface} protocol ip parent 1:0 prio 2 u32 match ip sport ${p} 0xffff flowid 1:1"$'\n'
                rb+="sudo tc filter add dev ${iface} protocol ip parent 1:0 prio 2 u32 match ip dport ${p} 0xffff flowid 1:1"$'\n'
            done
        fi

        if [[ "${ipv6_on}" == true ]]; then
            rb+="# IPv6: passthrough (prio 3) → class 1:2"$'\n'
            local line
            while IFS= read -r line || [[ -n "${line}" ]]; do
                [[ -n "${line}" ]] && rb+="${line}"$'\n'
            done < <(_nemesis_tc_emit_ipv6_passthrough_prio3 "${iface}")
            rb+="# IPv6: YDB sport/dport (prio 2) → class 1:1"$'\n'
            for p in "${CHAOS_YDB_PORTS_ARR[@]}"; do
                local hex_p=""
                printf -v hex_p '0x%x' "${p}"
                rb+="sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 2 u32 match ip6 sport ${hex_p} 0xffff flowid 1:1"$'\n'
                rb+="sudo tc filter add dev ${iface} protocol ipv6 parent 1:0 prio 2 u32 match ip6 dport ${hex_p} 0xffff flowid 1:1"$'\n'
            done
        fi

        rb+="sudo tc qdisc add dev ${iface} parent 1:2 handle 20: netem delay 0ms limit 262144"$'\n'
    done

    rb+=""$'\n'
    rb+="nohup bash -c 'sleep ${timeout_s}; while IFS= read -r _tcdev; do [[ -n \"\${_tcdev}\" ]] && sudo tc qdisc del dev \"\${_tcdev}\" root 2>/dev/null || true; done < /tmp/tc-chaos-ifaces.list; rm -f /tmp/tc-chaos-ifaces.list /tmp/tc-chaos.pid' >/dev/null 2>&1 &"$'\n'
    rb+="echo \$! > /tmp/tc-chaos.pid"$'\n'

    printf '%s' "${rb}"
}

nemesis_tc_netem_apply() {
    local host="$1" netem_params="$2" timeout_s="$3"
    chaos_ydb_ports_to_array
    chaos_net_require_any_stack || return 1
    chaos_net_ifaces_for_host "${host}"

    local ports_csv="${CHAOS_YDB_PORTS_ARR[*]}"
    ports_csv="${ports_csv// /,}"
    local ifcsv="${CHAOS_NET_IFACES_ARR[*]}"
    ifcsv="${ifcsv// /,}"
    local stacks=""
    chaos_net_ipv4_enabled && stacks+="IPv4 "
    chaos_net_ipv6_enabled && stacks+="IPv6 "
    stacks="${stacks%% }"

    log_chaos_apply "tc netem на ${host} ifaces=[${ifcsv}] stacks=[${stacks}] ports(sport|dport)=${ports_csv} [${netem_params}] timeout=${timeout_s}s"
    chaos_term_remote_cmd "ssh ${host}  tc prio+netem [${netem_params}] ifaces=${ifcsv}"

    local remote_script
    remote_script="$(_nemesis_tc_netem_remote_script "${netem_params}" "${timeout_s}")"

    chaos_log_remote_script "Удалённый скрипт tc (netem), хост ${host}" "${remote_script}"

    ssh "${SSH_OPTS[@]}" "${host}" "bash -s" <<< "${remote_script}"
}

# --- tbf на корне qdisc (тест 07), все интерфейсы из chaos_net ---

_nemesis_tc_tbf_remote_script() {
    local rate_mbit="$1" burst_bytes="$2" timeout_s="$3"
    local iface rb=""
    rb+="set -euo pipefail"$'\n'
    rb+="if [[ -f /tmp/tc-chaos.pid ]]; then"$'\n'
    rb+="  kill \"\$(cat /tmp/tc-chaos.pid)\" 2>/dev/null || true"$'\n'
    rb+="  rm -f /tmp/tc-chaos.pid"$'\n'
    rb+="fi"$'\n'
    rb+="rm -f /tmp/tc-chaos-ifaces.list"$'\n'
    for iface in "${CHAOS_NET_IFACES_ARR[@]}"; do
        rb+="sudo tc qdisc del dev ${iface} root 2>/dev/null || true"$'\n'
        rb+="printf '%s\\n' '${iface}' >> /tmp/tc-chaos-ifaces.list"$'\n'
    done
    for iface in "${CHAOS_NET_IFACES_ARR[@]}"; do
        rb+="echo '--- tc-tbf dev=${iface} ---'"$'\n'
        rb+="sudo tc qdisc add dev ${iface} root tbf rate ${rate_mbit}mbit burst ${burst_bytes} latency 50ms"$'\n'
    done
    rb+="nohup bash -c 'sleep ${timeout_s}; while IFS= read -r _tcdev; do [[ -n \"\${_tcdev}\" ]] && sudo tc qdisc del dev \"\${_tcdev}\" root 2>/dev/null || true; done < /tmp/tc-chaos-ifaces.list; rm -f /tmp/tc-chaos-ifaces.list /tmp/tc-chaos.pid' >/dev/null 2>&1 &"$'\n'
    rb+="echo \$! > /tmp/tc-chaos.pid"$'\n'
    printf '%s' "${rb}"
}

nemesis_tc_tbf_apply() {
    local host="$1" rate_mbit="$2" burst_bytes="$3" timeout_s="$4"
    chaos_net_ifaces_for_host "${host}"
    local ifcsv="${CHAOS_NET_IFACES_ARR[*]}"
    ifcsv="${ifcsv// /,}"

    log_chaos_apply "tc tbf на ${host} ifaces=[${ifcsv}] rate=${rate_mbit}mbit burst=${burst_bytes} timeout=${timeout_s}s"
    chaos_term_remote_cmd "ssh ${host}  tc tbf rate ${rate_mbit}mbit burst ${burst_bytes}, auto-undo через ${timeout_s}s"

    local remote_script
    remote_script="$(_nemesis_tc_tbf_remote_script "${rate_mbit}" "${burst_bytes}" "${timeout_s}")"

    chaos_log_remote_script "Удалённый скрипт tc (tbf), хост ${host}" "${remote_script}"

    ssh "${SSH_OPTS[@]}" "${host}" "bash -s" <<< "${remote_script}"
}

nemesis_tc_teardown() {
    local host="$1"
    chaos_net_ifaces_for_host "${host}"
    chaos_term_remote_cmd "ssh ${host}  tc qdisc del root (все chaos-интерфейсы) + kill bg-timer"

    local rb=""
    rb+="set -euo pipefail"$'\n'
    rb+="if [[ -f /tmp/tc-chaos.pid ]]; then"$'\n'
    rb+="  kill \"\$(cat /tmp/tc-chaos.pid)\" 2>/dev/null || true"$'\n'
    rb+="  rm -f /tmp/tc-chaos.pid"$'\n'
    rb+="fi"$'\n'
    for iface in "${CHAOS_NET_IFACES_ARR[@]}"; do
        rb+="sudo tc qdisc del dev ${iface} root 2>/dev/null || true"$'\n'
    done
    rb+="rm -f /tmp/tc-chaos-ifaces.list"$'\n'

    chaos_log_remote_script "Удалённый скрипт tc teardown, хост ${host}" "${rb}"
    ssh "${SSH_OPTS[@]}" "${host}" "bash -s" <<< "${rb}"
}

nemesis_tc_check() {
    local host="$1"
    chaos_net_ifaces_for_host "${host}"
    chaos_ydb_ports_to_array
    local port="${CHAOS_YDB_PORTS_ARR[0]:-0}"

    local target=""
    local _h
    for _h in "${CLUSTER_HOSTS[@]}"; do
        [[ "${_h}" != "${host}" ]] && { target="${_h}"; break; }
    done

    chaos_term_remote_cmd "ssh ${host}  tc qdisc show + hping3 RTT"

    local try_v6=0
    chaos_net_ipv6_enabled && try_v6=1

    local qiface
    qiface="$(printf '%q ' "${CHAOS_NET_IFACES_ARR[@]}")"

    ssh "${SSH_OPTS[@]}" "${host}" "bash -s" <<REMOTE
set -euo pipefail
CHAOS_IFACES="${qiface}"
for iface in \${CHAOS_IFACES}; do
  echo ''
  echo "=== dev \${iface} ==="
  chaos=\$(tc qdisc show dev "\${iface}" | awk '
/netem.*root/{
    for(i=1;i<=NF;i++) if(\$i=="limit"){s=""; for(j=i+2;j<=NF;j++) s=s (j>i+2?" ":"") \$j; print "[netem] " s; exit}
}
/tbf.*root/{
    r=""; b=""; l=""
    for(i=1;i<=NF;i++){
        if(\$i=="rate")  r=\$(i+1)
        if(\$i=="burst") b=\$(i+1)
        if(\$i=="lat")   l=\$(i+1)
    }
    print "[tbf] rate=" r " burst=" b " latency=" l; exit
}
/netem.*parent 1:1/{
    for(i=1;i<=NF;i++) if(\$i=="limit"){s=""; for(j=i+2;j<=NF;j++) s=s (j>i+2?" ":"") \$j; if(s!="") {print "[netem/YDB-ports] " s; exit}}
}')
  if [[ -n "\${chaos}" ]]; then
    echo "${host} (\${iface})  chaos: ACTIVE   \${chaos}"
  else
    root=\$(tc qdisc show dev "\${iface}" | awk '/root/{print \$2; exit}')
    echo "${host} (\${iface})  chaos: inactive  root=\${root:-none}"
  fi
done

[[ -z '${target}' ]] && exit 0

echo ''
if ! command -v hping3 >/dev/null 2>&1; then
  echo 'RTT: hping3 не найден (sudo yum/apt install hping3)'
  exit 0
fi
target_ip=""
if [[ ${try_v6} -eq 1 ]]; then
  target_ip=\$(getent ahostsv6 '${target}' 2>/dev/null | awk 'NR==1{print \$1}')
fi
if [[ -z "\${target_ip}" ]]; then
  target_ip=\$(getent hosts '${target}' 2>/dev/null | awk 'NR==1{print \$1}')
fi
if [[ -z "\${target_ip}" ]]; then
  echo 'RTT: не удалось разрешить IP для ${target}'
  exit 0
fi
echo "RTT → \${target_ip} (${target}):${port}  sport=${port}  (10 проб)"
if [[ "\${target_ip}" == *:* ]]; then
  sudo hping3 -6 -S -p ${port} -s ${port} -c 10 "\${target_ip}" 2>&1 | awk '
    /rtt=/ {
        split(\$0, a, "rtt="); split(a[2], b, " "); t = b[1] + 0
        n = int(t * 5 + 0.5)
        bar = ""; for (i = 0; i < n; i++) bar = bar "#"
        printf "%7.2f ms  |%s\n", t, bar
        sum += t; cnt++
    }
    END { if (cnt > 0) printf "   avg: %.2f ms\n", sum / cnt }'
else
  sudo hping3 -S -p ${port} -s ${port} -c 10 "\${target_ip}" 2>&1 | awk '
    /rtt=/ {
        split(\$0, a, "rtt="); split(a[2], b, " "); t = b[1] + 0
        n = int(t * 5 + 0.5)
        bar = ""; for (i = 0; i < n; i++) bar = bar "#"
        printf "%7.2f ms  |%s\n", t, bar
        sum += t; cnt++
    }
    END { if (cnt > 0) printf "   avg: %.2f ms\n", sum / cnt }'
fi
REMOTE
}

nemesis_tc_netem_apply_all() {
    log_chaos_apply "tc netem [${NETEM_PARAMS}] на ${#@} хостах timeout=${TIMEOUT}s"
    parallel_for_hosts nemesis_tc_netem_apply "$@" -- "${NETEM_PARAMS}" "${TIMEOUT}"
}

nemesis_tc_tbf_apply_all() {
    log_chaos_apply "tc tbf rate=${RATE}mbit burst=${BURST}b на ${#@} хостах timeout=${TIMEOUT}s"
    parallel_for_hosts nemesis_tc_tbf_apply "$@" -- "${RATE}" "${BURST}" "${TIMEOUT}"
}

nemesis_tc_teardown_all() {
    log "Снятие tc с ${#@} хостов"
    parallel_for_hosts nemesis_tc_teardown "$@" || return $?
}
