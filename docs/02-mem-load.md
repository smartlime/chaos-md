# Тест 02: Нагрузка на память (mem load)

## Справка (`./02-mem-load.sh -h`)

Обязательно **`-1`**, **`-4`** или **`-A`**. Ключи: `-m`, `-R`, `-t`, `-T`, `-D`.

```bash
./02-mem-load.sh -1 -m 90 -t 1200 -T 1300
./02-mem-load.sh -4 -t 600
./02-mem-load.sh -D
```

## Что делает тест

Нагружает оперативную память через ChaosBlade. На каждую ноду запускаются два эксперимента:
1. **RAM heap** — выделяет `N%` физической памяти через heap (Java-like alloc)
2. **Page cache** — заполняет страничный кэш ядра

Оба эксперимента работают одновременно и снимаются автоматически по таймауту (`--timeout`), встроенному в команду blade.

## Команды

### Шаг 1: одна нода (1200с по умолчанию)

```bash
sudo ~/blade create mem load \
  --mode ram \
  --mem-percent 90 \
  --rate 500 \
  --avoid-being-killed \
  --include-buffer-cache \
  --timeout 1200

sudo ~/blade create mem load \
  --mode cache \
  --mem-percent 90 \
  --avoid-being-killed \
  --timeout 1200
```

### Шаг 2: весь ДЦ (600с по умолчанию)

Те же команды с `--timeout 600`, запускаются на 4 нодах параллельно.

## Параметры blade

| Параметр              | Описание                                                         |
|-----------------------|------------------------------------------------------------------|
| `--mode ram`          | Heap-аллокация: занимает физическую память через malloc/alloc    |
| `--mode cache`        | Заполнение страничного кэша ядра                                 |
| `--mem-percent N`     | Целевой процент занятой памяти (от общего объёма)               |
| `--rate N`            | Скорость заполнения RAM в МБ/с                                   |
| `--avoid-being-killed` | Снижает OOM-score — снижает риск, что OOM-killer убьёт blade    |
| `--include-buffer-cache` | Учитывать buffer cache при расчёте `--mem-percent` (для RAM) |
| `--timeout N`         | Автоматически снять нагрузку через N секунд                     |

## Управление UID

UID каждого эксперимента сохраняется в:
- `logs/02-mem-load.<host>.ram.uid`
- `logs/02-mem-load.<host>.cache.uid`

Для ручной остановки:
```bash
./02-mem-load.sh -D
# или вручную:
ssh <host> "sudo ~/blade destroy <uid>"
```

## Что наблюдать

- Рост потребления памяти: `free -h`, Grafana → Memory Used
- OOM events в `/var/log/messages` или `dmesg`
- Деградация запросов YDB при нехватке памяти
- Срабатывание swap
