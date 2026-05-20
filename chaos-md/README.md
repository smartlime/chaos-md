# chaos-md — TUI диспетчер Chaos MD

Rust-приложение на [ratatui](https://github.com/ratatui-org/ratatui). Предоставляет единый экран для запуска хаос-тестов, наблюдения за PTY-выводом, статусом немезисов, ASCII-часами и timeline'ом событий.

## Бинарники

Сборка производится из этого каталога через Docker (без rustup на хосте):

```bash
# Из корня репозитория:
make orch      # все платформы: Linux x86_64, aarch64 (musl) + macOS (текущая arch)
make dev       # только macOS, нативно (быстро, без Docker)
make package   # orch + полный архив dist/disarray-YYYY-MM-DD.tar.gz
```

Результат — в `dist/` (корень репозитория):

| Файл | Платформа |
|------|-----------|
| `chaos-md.x86_64` | Linux x86_64 (musl static) |
| `chaos-md.aarch64` | Linux aarch64 (musl static) |
| `chaos-md.darwin_arm64` | macOS Apple Silicon |
| `chaos-md.darwin_x86_64` | macOS Intel |

Лаунчер `dist/chaos-md` (скрипт) выбирает нужный бинарник по `uname -m`.

## Требования для сборки

- Docker Desktop (для Linux-таргетов через `make orch`)
- Cargo / Rust (только для `make dev` на Mac)

## Разработка

```bash
# Запустить из корня репозитория (режим разработки):
./chaos-md.sh --dev

# Или напрямую:
cd chaos-md
cargo run --release -- --root ..

# Сборка бинарника для текущего Mac без Docker:
cargo build --release
# → target/release/chaos-md
```

Флаг `--root` указывает корень репозитория — там `chaos-md.sh` ищет тест-скрипты, `logs/timeline.log`, `env.sh`.

## Опции запуска

```
./chaos-md.sh [ОПЦИИ]

  --headless              Запустить очередь без TUI (для автоматизации)
  --tests 04,05,11        Список тестов через запятую
  -t, --time SEC          Длительность каждого теста
  -p, --pause SEC         Пауза между тестами
  --node                  Включить фазу -1 (одна нода)
  --dc                    Включить фазу -4 (весь ДЦ)
  -d, --dry-run           Без реальных SSH-вызовов
  --version               Версия
  -h, --help              Справка
```

## Архитектура

```
src/
├── main.rs           — точка входа, CLI (clap), инициализация tokio runtime
├── app.rs            — верхний уровень приложения: event loop, state machine
├── catalog.rs        — каталог тестов (чтение из NN-*.sh)
├── queue.rs          — очередь запусков и её состояние
├── runner.rs         — запуск bash-тестов в PTY (portable-pty)
├── state.rs          — персистентное состояние (JSON)
├── watcher.rs        — inotify-слежение за logs/timeline.log
├── ansi.rs           — ANSI → ratatui Text конвертация
├── theme.rs          — цветовая схема
└── ui/
    ├── mod.rs        — компоновка зон экрана
    ├── selector.rs   — панель выбора тестов и параметров
    ├── log.rs        — PTY-лог теста (скроллируемый)
    ├── timeline.rs   — лента событий из logs/timeline.log
    ├── clock.rs      — ASCII-часы
    ├── status.rs     — строка статуса
    ├── progress.rs   — прогресс-бар теста
    ├── remaining_time.rs — таймер обратного отсчёта
    ├── config_dialog.rs  — диалог настроек
    └── dialog.rs     — общий диалоговый виджет
```
