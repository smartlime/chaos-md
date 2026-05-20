# URLS.md — список URL для сбора метрик YDB

Примеры ниже используют три хоста (`ydb-node-{1,2,3}.example.com`) и порты `8765,8767,8768`. На своём стенде подставьте значения из **`CLUSTER_HOSTS`**, **`YDB_MON_PORTS`** и **`YDB_MON_PD_PORT`** (`env.sh`).

## Сравнение конфигураций

### Prometheus (эталон)

- **Scheme**: HTTPS  
- **TLS**: `ca.crt`  
- **Targets**: два file_sd — `ydb_storage.yml` (8765) и `ydb_database.yml` (8767).

### VictoriaMetrics (`grafana/scrape.yml` + файлы из `01-victoria.sh`)

- **Scheme**: HTTPS  
- **TLS**: `insecure_skip_verify: true`  
- **Targets**:
  - **`/etc/prometheus/ydbd-mon.yml`** — все хосты кластера × **каждый** порт из `YDB_MON_PORTS`. Большинство job'ов (`ydb/auth`, `ydb/ydb`, `ydb/topics`, …) читают только этот файл.
  - **`/etc/prometheus/ydbd-storage.yml`** — те же хосты × только `YDB_MON_PD_PORT` (порт мониторинга узла хранения, по умолчанию 8765). Используются только job'ы **`ydb/pdisks`** и **`ydb/vdisks`**.

Файла **`ydbd-database.yml`** в текущей схеме нет: «динамические» порты входят в общий список `YDB_MON_PORTS`; метка `container` для 8765 — `ydb-static`, для остальных — `ydb-dynamic`, плюс метка **`mon_port`**.

---

## Пример: `counters=ydb` (`/counters/counters=ydb/name_label=name/prometheus`)

### Порт 8765

```
https://ydb-node-1.example.com:8765/counters/counters=ydb/name_label=name/prometheus
https://ydb-node-2.example.com:8765/counters/counters=ydb/name_label=name/prometheus
https://ydb-node-3.example.com:8765/counters/counters=ydb/name_label=name/prometheus
```

### Порт 8767

```
https://ydb-node-1.example.com:8767/counters/counters=ydb/name_label=name/prometheus
https://ydb-node-2.example.com:8767/counters/counters=ydb/name_label=name/prometheus
https://ydb-node-3.example.com:8767/counters/counters=ydb/name_label=name/prometheus
```

### Порт 8768

```
https://ydb-node-1.example.com:8768/counters/counters=ydb/name_label=name/prometheus
https://ydb-node-2.example.com:8768/counters/counters=ydb/name_label=name/prometheus
https://ydb-node-3.example.com:8768/counters/counters=ydb/name_label=name/prometheus
```

---

## Другие counters (те же хосты и порты, меняется только путь)

Шаблон: `https://<host>:<port>/counters/counters=<имя>/prometheus`

Для каждого job'а из `scrape.yml` (кроме `node`, `ydb/healthcheck`) перечислите все пары `(host, port)` из `ydbd-mon.yml`: `host ∈ CLUSTER_HOSTS`, `port ∈ YDB_MON_PORTS`.

Примеры для **`counters=auth`** (3 хоста × 3 порта = 9 URL):

```
https://ydb-node-1.example.com:8765/counters/counters=auth/prometheus
https://ydb-node-2.example.com:8765/counters/counters=auth/prometheus
https://ydb-node-3.example.com:8765/counters/counters=auth/prometheus
https://ydb-node-1.example.com:8767/counters/counters=auth/prometheus
https://ydb-node-2.example.com:8767/counters/counters=auth/prometheus
https://ydb-node-3.example.com:8767/counters/counters=auth/prometheus
https://ydb-node-1.example.com:8768/counters/counters=auth/prometheus
https://ydb-node-2.example.com:8768/counters/counters=auth/prometheus
https://ydb-node-3.example.com:8768/counters/counters=auth/prometheus
```

Аналогично для `compile`, `config`, `coordinator`, `kqp`, `proxy`, `tablets`, `utils`, `topics`, … — тот же набор хостов и портов.

### `counters=vdisks` и `counters=pdisks`

Только **`YDB_MON_PD_PORT`** — порт мониторинга узла хранения (по умолчанию 8765):

```
https://ydb-node-1.example.com:8765/counters/counters=vdisks/prometheus
https://ydb-node-2.example.com:8765/counters/counters=vdisks/prometheus
https://ydb-node-3.example.com:8765/counters/counters=vdisks/prometheus
```

---

## Итого (пример для трёх нод)

- **Хостов**: 3  
- **`YDB_MON_PORTS`**: три порта → **9** endpoint'ов на один тип counter в job'ах, которые читают `ydbd-mon.yml`.  
- **pdisks / vdisks**: **3** endpoint'а (только `YDB_MON_PD_PORT`).

**Метки (file_sd):**

- `container`: `ydb-static` для порта 8765, иначе `ydb-dynamic`.  
- `mon_port`: строка с номером порта.  
- `instance`: hostname без порта (relabel из `__address__`).  
- `database`: путь БД из `YDB_DATABASE` (по умолчанию `/Root/db1`).

**Префиксы имён метрик** — как в `scrape.yml` (`metric_relabel_configs`: `ydb_$1`, `auth_$1`, …).
