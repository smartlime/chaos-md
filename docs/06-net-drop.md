# Тест 06: блокировка YDB-интерконнекта на одной ноде

## Справка (`./06-net-drop.sh -h`)

Только **`-1`**. Порты из **`YDB_PORTS`** (список и диапазоны). Ключи: **`--drop`**, `-t`, `-C`, `-D`.

```bash
./06-net-drop.sh -1 -t 600              # по умолчанию REJECT (TCP RST)
./06-net-drop.sh -1 --drop -t 600       # тихий DROP
./06-net-drop.sh -C
./06-net-drop.sh -D
```

Реализация: `nemesis/iptables.sh`. ДЦ-вариант — [тест 11](11-dc-drop.md).

## REJECT vs DROP

| Режим | Как включить | Поведение |
|-------|--------------|-----------|
| **REJECT** (по умолчанию) | без флагов | `-j REJECT --reject-with tcp-reset` — удалённая сторона быстро получает RST |
| **DROP** | `--drop` | пакеты отбрасываются без ответа; соединения «висят» до TCP-таймаута |

Оба режима режут одни и те же порты и интерфейсы; отличается только реакция стека на заблокированный трафик.

## Что делает тест

На **одной** ноде блокирует TCP-трафик по портам из `YDB_PORTS` на **всех** интерфейсах, перечисленных для хоста в `NET_IFACES` / `NET_IFACES_TABLE` (важно при двух NIC). Остальные ноды кластера для внешних клиентов доступны как раньше — изолируется только выбранная нода.

SSH (порт 22) и прочий трафик вне `YDB_PORTS` не затрагиваются.

## Цепочка и правила

**Подготовка (один раз):** `prepare-hosts.sh` создаёт пользовательскую цепочку **`CHAOS_IPTABLES_CHAIN`** (по умолчанию `YDB_CHAOS_FW`) и вставляет jump в начало INPUT/OUTPUT (IPv4 и, при `CHAOS_NET_IPV6=true`, IPv6).

**Применение:** на каждый порт из `YDB_PORTS` (после раскрытия диапазонов) и каждый iface — **четыре** правила в эту цепочку:

| Направление | Match | Смысл |
|-------------|-------|--------|
| INPUT | `-i iface --dport` | не принимать входящие к локальным портам YDB |
| INPUT | `-i iface --sport` | не принимать входящие с sport = порт YDB (ответы соседей) |
| OUTPUT | `-o iface --sport` | не отправлять с локального source port = порт YDB |
| OUTPUT | `-o iface --dport` | не инициировать исходящие к портам YDB через этот NIC |

Пример для одного порта **19001** и iface **eth0** (режим REJECT):

```bash
sudo iptables -A YDB_CHAOS_FW -p tcp -i eth0 --dport 19001 -j REJECT --reject-with tcp-reset
sudo iptables -A YDB_CHAOS_FW -p tcp -i eth0 --sport 19001 -j REJECT --reject-with tcp-reset
sudo iptables -A YDB_CHAOS_FW -p tcp -o eth0 --sport 19001 -j REJECT --reject-with tcp-reset
sudo iptables -A YDB_CHAOS_FW -p tcp -o eth0 --dport 19001 -j REJECT --reject-with tcp-reset
```

С `--drop` вместо `REJECT …` — `-j DROP`. Повторяется для всех портов из `YDB_PORTS` и всех iface; при IPv6 — те же правила через `ip6tables`.

## Снятие

Скрипт сбрасывает **всю цепочку** (`iptables -F YDB_CHAOS_FW`), а не удаляет правила по одному:

```bash
sudo iptables  -F YDB_CHAOS_FW
sudo ip6tables -F YDB_CHAOS_FW
```

## Проверка

```bash
./06-net-drop.sh -C
./06-net-drop.sh -C node.example.net
```

Или на ноде:

```bash
sudo iptables-save  | grep YDB_CHAOS_FW
sudo ip6tables-save | grep YDB_CHAOS_FW
```

## Механика скрипта

`chaos_run_window`: apply → локальное ожидание `-t` с тикером → явный teardown. **Фонового nohup на ноде нет** (в отличие от tc, disk, proc, systemd).

`-D` — немедленный teardown без ожидания.

## Параметры

| Параметр | Ключ | По умолчанию |
|----------|------|--------------|
| Длительность фазы, с | `-t` | `DEFAULT_CHAOS_TIMEOUT` (обычно 1200) |
| Режим DROP | `--drop` | выкл. (REJECT) |
| Порты | — | `YDB_PORTS` в `env.sh` |
| Интерфейсы | — | `NET_IFACES_TABLE` / `NET_IFACES` |
| Проверка | `-C` [HOST] | — |
| Снять | `-D` | — |

## Что наблюдать

- Потеря связи ноды с кластером в мониторинге YDB
- Переход партиций в нездоровое состояние
- Рост ошибок / таймаутов запросов (профиль зависит от REJECT vs DROP)
- Время переключения на другие реплики
- Сходимость после `-t` или `-D`
