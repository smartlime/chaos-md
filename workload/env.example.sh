#!/usr/bin/env bash
# Образец workload/env.local.sh.
# Скопируйте в env.local.sh и заполните значения под свой стенд.
# В реальных адресах (хост, endpoint, VM URL) дефолтов нет — без них скрипты падают.

# Хост, на котором будет работать нагрузка. SSH-алиас или FQDN.
WL_REMOTE_HOST="ydb-client.example.com"
# WL_REMOTE_USER="${USER}"
# WL_REMOTE_DEST="ydb-workload"

# YDB. Способ 1 — endpoint + database; способ 2 — профиль ydb CLI.
WL_YDB_ENDPOINT="grpc://ydb-node-01.example.com:2135"
WL_YDB_DATABASE="/Root/db1"
# WL_YDB_PROFILE=""

# Префикс под тестовые таблицы. Можно оставить дефолт — он уже "chaos-load/<user>".
# WL_PATH_PREFIX="chaos-load/${USER}"

# VictoriaMetrics — куда лить метрики.
WL_VM_WRITE_URL="http://mon-host.example.com:8428/api/v1/import/prometheus"
# WL_VM_INSECURE="1"

# Опционально — переопределить имя в графиках.
# WL_APPLICATION="chaos-stock"

# Опционально — параметры нагрузки.
# WL_RUN_THREADS=64
# WL_RUN_DURATION=3600
# WL_SCENARIOS="add-rand-order put-rand-order rand-user-hist"
