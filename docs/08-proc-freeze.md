# Тест 08: заморозка процессов ydbd (proc freeze)

## Справка (`./08-proc-freeze.sh -h`)

```
Использование: 08-proc-freeze.sh -1 [ОПЦИИ]

Тест 08: заморозка процессов ydbd (путь: DEFAULT_YDBD_BIN, по умолчанию /opt/ydb/bin/ydbd).

Обязательно:
  -1, --single          Запуск сценария

Опции:
  -t, --time SEC        Длительность заморозки, с
  -H, --host HOST       Хост
  -C [HOST]             Состояние процессов
  -D                    Разморозить (SIGCONT)
  -h, --help            Справка
```

## Что делает тест

Отправляет `SIGSTOP` процессу(ам) **ydbd** — ядро замораживает процесс: он не получает CPU,
не обрабатывает запросы. Через `-t` секунд автоматически отправляется `SIGCONT`.

## Несколько процессов на хосте

На ноде может быть несколько процессов **ydbd** (tenant/database и т.д.), с разными `--ic-port`. Пример вывода (пути — из `DEFAULT_YDBD_BIN`):

```
264633  S   /opt/ydb/bin/ydbd ... --ic-port 31003
267026  S   /opt/ydb/bin/ydbd ... --ic-port 31013
```

Проверка:

```bash
./08-proc-freeze.sh -C
./08-proc-freeze.sh -C node.example.net
```

## Команды вручную

```bash
pgrep -a -f /opt/ydb/bin/ydbd
sudo kill -STOP $(pgrep -f /opt/ydb/bin/ydbd)
sudo kill -CONT $(pgrep -f /opt/ydb/bin/ydbd)
```

`sudo` обычно обязателен: процесс не под вашим UID.

## Механика

1. `pgrep -f` по пути бинарника **ydbd**.
2. `SIGSTOP` всем найденным PID.
3. Фоновый таймер через `-t` секунд — `SIGCONT`.
4. `-D` — немедленный `SIGCONT` и снятие таймера.

## Параметры

| Параметр | Ключ | По умолчанию |
|---|---|---|
| Длительность, с | `-t` | `DEFAULT_CHAOS_TIMEOUT` |
| Хост | `-H` | `SINGLE_HOST` |
| Проверка | `-C` [HOST] | — |
| Разморозка | `-D` | — |

Бинарник: `DEFAULT_YDBD_BIN` в `env.sh`.
