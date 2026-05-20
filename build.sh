#!/usr/bin/env bash
# Сборка дистрибутива: белый список → dist/${CODENAME}-YYYY-MM-DD.tar.gz
#
# Раскладка в архиве: один каталог верхнего уровня — ${CODENAME}/ (по умолчанию disarray/),
# внутри — тест-скрипты, lib/, nemesis/, docs/, workload/, dist/ с бинарниками Chaos MD и т.д.
# Лаунчер ./disarray/chaos-md.sh (после распаковки: cd disarray && ./chaos-md.sh).
#
# Не входят: build.sh, env.sh, env.local.sh, private/, dist/*.tar.gz (кроме копируемых артефактов), скрытые файлы.

set -euo pipefail

CODENAME="disarray"

# macOS (HFS+/APFS): без этого BSD tar кладёт в архив AppleDouble `._*`.
export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

DATE="$(date +%Y-%m-%d)"
NAME="${CODENAME}-${DATE}"
DIST="${ROOT}/dist"
mkdir -p "${DIST}"
ARCHIVE="${DIST}/${NAME}.tar.gz"

RELEASE=(
    01-cpu-load.sh
    02-mem-load.sh
    03-disk-fail.sh
    04-net-delay.sh
    05-net-loss.sh
    06-net-drop.sh
    07-net-bw.sh
    08-proc-freeze.sh
    09-proc-kill.sh
    10-rolling-upgrade.sh
    11-dc-drop.sh
    12-server-stop.sh
    README.md
    env.example.sh
    chaos-md.sh
    reset-tc-qdisc.sh
    rolling-restart.sh
    run-all.sh
    set-net-delay.sh
    setup-blade.sh
    sync-to-remote.sh
    prepare-hosts.sh
    all-forwards.sh
)
# Каталог grafana/ намеренно НЕ входит в дистрибутив: это инструменты для
# разворачивания мониторинга на стенде, а не часть «продуктовых» chaos-тестов.

for f in "${RELEASE[@]}"; do
    if [[ ! -f "${ROOT}/${f}" ]]; then
        echo "Нет файла релиза: ${f}" >&2
        exit 1
    fi
done

# Staging: верхний уровень архива — ${CODENAME}/
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

PKG="${STAGE}/${CODENAME}"
mkdir -p "${PKG}"

echo "Staging: ${PKG}"

# Корневые файлы релиза.
for f in "${RELEASE[@]}"; do
    cp "${ROOT}/${f}" "${PKG}/${f}"
done

# lib/ и nemesis/ — рекурсивно, с сохранением структуры.
while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    mkdir -p "${PKG}/$(dirname "${f}")"
    cp "${ROOT}/${f}" "${PKG}/${f}"
done < <(find lib nemesis -type f -name '*.sh' ! -path '*/\.*' ! -name '._*' 2>/dev/null | sort)

# docs/ — полностью.
if [[ -d "${ROOT}/docs" ]]; then
    while IFS= read -r f; do
        [[ -n "${f}" ]] || continue
        mkdir -p "${PKG}/$(dirname "${f}")"
        cp "${ROOT}/${f}" "${PKG}/${f}"
    done < <(find docs -type f ! -path '*/\.*' ! -name '._*' ! -name '.DS_Store' 2>/dev/null | sort)
else
    echo "ПРЕДУПРЕЖДЕНИЕ: каталог docs/ не найден." >&2
fi

# workload/ — нагрузка и вспомогательные скрипты (если есть).
if [[ -d "${ROOT}/workload" ]]; then
    while IFS= read -r f; do
        [[ -n "${f}" ]] || continue
        mkdir -p "${PKG}/$(dirname "${f}")"
        cp "${ROOT}/${f}" "${PKG}/${f}"
    done < <(find workload -type f ! -path '*/\.*' ! -name '._*' ! -name '.DS_Store' 2>/dev/null | sort)
else
    echo "ПРЕДУПРЕЖДЕНИЕ: каталог workload/ не найден." >&2
fi

# Chaos MD: бинарники — в dist/ внутри пакета (chaos-md.sh ищет ${REPO_ROOT}/dist/chaos-md.*).
mkdir -p "${PKG}/dist"
PROF_FOUND=false
for arch in x86_64 aarch64; do
    src="${ROOT}/dist/chaos-md.${arch}"
    if [[ -f "${src}" ]]; then
        cp "${src}" "${PKG}/dist/chaos-md.${arch}"
        chmod +x "${PKG}/dist/chaos-md.${arch}"
        PROF_FOUND=true
    fi
done
for darwin_arch in darwin_arm64 darwin_x86_64; do
    src="${ROOT}/dist/chaos-md.${darwin_arch}"
    if [[ -f "${src}" ]]; then
        cp "${src}" "${PKG}/dist/chaos-md.${darwin_arch}"
        chmod +x "${PKG}/dist/chaos-md.${darwin_arch}"
        PROF_FOUND=true
    fi
done
if [[ "${PROF_FOUND}" == false ]]; then
    echo "ПРЕДУПРЕЖДЕНИЕ: dist/chaos-md.{x86_64,aarch64,darwin_*} не найдены — архив без TUI." >&2
    echo "  Запустите: make orch" >&2
fi

# ChaosBlade: архив для setup-blade.sh — тоже в dist/ пакета.
# setup-blade.sh ищет его сначала рядом с собой, потом в dist/.
BLADE_FOUND=false
for archive in "${ROOT}/dist"/chaosblade-*.tar.gz; do
    if [[ -f "${archive}" ]]; then
        cp "${archive}" "${PKG}/dist/$(basename "${archive}")"
        echo "  + $(basename "${archive}") ($(du -sh "${archive}" | cut -f1))"
        BLADE_FOUND=true
    fi
done
if [[ "${BLADE_FOUND}" == false ]]; then
    echo "ПРЕДУПРЕЖДЕНИЕ: dist/chaosblade-*.tar.gz не найдены — setup-blade.sh не сработает." >&2
    echo "  Скачайте с https://github.com/chaosblade-io/chaosblade/releases в dist/" >&2
fi

# Архив: один каталог верхнего уровня ${CODENAME}/
tar -czf "${ARCHIVE}" \
    --exclude='._*' \
    --exclude='.DS_Store' \
    -C "${STAGE}" "${CODENAME}"

echo ""
echo "Создан: ${ARCHIVE}"
ls -lh "${ARCHIVE}"
tar -tzf "${ARCHIVE}" | head -25
