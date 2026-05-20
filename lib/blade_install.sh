#!/usr/bin/env bash
# Установка ChaosBlade на удалённый хост: ~/dist/<архив> + распаковка + симлинк ~/blade.
# Нужен полный tar.gz (каталог chaosblade-* с бинарником blade и модулями).

blade_default_archive_path() {
    local script_dir="$1"
    local name="${BLADE_ARCHIVE_NAME:-chaosblade-1.8.0-linux_amd64.tar.gz}"
    local f
    if [[ -f "${script_dir}/${name}" ]]; then
        printf '%s\n' "${script_dir}/${name}"
        return
    fi
    if [[ -f "${script_dir}/dist/${name}" ]]; then
        printf '%s\n' "${script_dir}/dist/${name}"
        return
    fi
    shopt -s nullglob
    for f in "${script_dir}/dist"/chaosblade-*linux*.tar.gz "${script_dir}"/chaosblade-*linux*.tar.gz; do
        if [[ -f "${f}" ]]; then
            printf '%s\n' "${f}"
            shopt -u nullglob
            return
        fi
    done
    shopt -u nullglob
    printf '%s\n' "${script_dir}/dist/${name}"
}

# blade_install_on_host <host> <локальный_путь_к_tar.gz>
blade_install_on_host() {
    local host="$1"
    local local_archive="$2"

    if [[ ! -f "${local_archive}" ]]; then
        echo "blade_install_on_host: нет файла ${local_archive}" >&2
        return 1
    fi

    local bn ev
    bn="$(basename "${local_archive}")"
    ev="ARCHIVE=$(printf '%q' "${bn}")"

    ssh "${SSH_OPTS[@]}" "${host}" "mkdir -p \"\${HOME}/dist\""
    scp "${SSH_OPTS[@]}" "${local_archive}" "${host}:~/dist/${bn}"

    ssh "${SSH_OPTS[@]}" "${host}" "${ev} bash -s" <<'REMOTE'
set -euo pipefail
DIST_DIR="${HOME}/dist"
cd "${DIST_DIR}"
echo "prepare-hosts: распаковка ChaosBlade в ${DIST_DIR} ..."
rm -f "${HOME}/blade"
shopt -s nullglob
for d in "${DIST_DIR}"/chaosblade-*; do
    [[ -d "${d}" ]] && rm -rf "${d}"
done
shopt -u nullglob
tar -xzf "${ARCHIVE}"
ROOT="$(find "${DIST_DIR}" -maxdepth 1 -type d -name 'chaosblade-*' | head -1)"
if [[ -z "${ROOT}" || ! -f "${ROOT}/blade" ]]; then
    echo "ОШИБКА: после распаковки нет каталога chaosblade-*/blade в ${DIST_DIR}" >&2
    ls -la "${DIST_DIR}" >&2 || true
    exit 1
fi
chmod +x "${ROOT}/blade"
ln -sfn "${ROOT}/blade" "${HOME}/blade"
echo "blade -> ${ROOT}/blade"
"${HOME}/blade" version 2>&1 || true
REMOTE
}
