# Тест 10: rolling upgrade бинарника ydbd

## Справка (`./10-rolling-upgrade.sh -h`)

```
Использование: 10-rolling-upgrade.sh -1 [ОПЦИИ]

Обязательно: -1, --single

Опции:
  -f, --file PATH       Архив дистрибутива (внутри должен быть */bin/ydbd)
  -t, --time SEC        Время работы с новым бинарником до сценария отката
  -H, --host HOST
  -C [HOST]             Версия бинарника и статус юнитов
  -D                    Немедленный откат
  -h, --help
```

Дистрибутив по умолчанию: `dist/ydbd-package.tar.xz` или переменная `ROLLING_UPGRADE_DIST`.

## Сценарий

1. Копирование архива на хост (если нужно).
2. Остановка tenant-юнитов (маска `YDBD_TENANT_UNIT_GLOB`) и storage (`YDBD_STORAGE_SERVICE`). В документации для внешнего стенда ориентир: **`ydbd-database-a.service`**, **`ydbd-storage.service`** — реальные имена задаются в `env.sh`.
3. Бэкап текущего бинарника в `~/ydbd_backup/ydbd.orig`.
4. Распаковка нового `ydbd` из архива и установка в путь **`DEFAULT_YDBD_BIN`** (по умолчанию `/opt/ydb/bin/ydbd`).
5. Запуск сервисов, наблюдение `-t` секунд.
6. Откат: снова стоп → восстановление из бэкапа → старт.

## Примеры команд на хосте (ориентир)

Подставьте реальные имена юнитов из `env.sh`:

```bash
sudo systemctl stop 'ydbd-database-a@*.service'   # фактически — YDBD_TENANT_UNIT_GLOB
sudo systemctl stop ydbd-storage.service           # YDBD_STORAGE_SERVICE
sudo cp /opt/ydb/bin/ydbd ~/ydbd_backup/ydbd.orig
# … замена бинарника …
sudo systemctl start ydbd-storage.service
```
