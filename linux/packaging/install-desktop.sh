#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_ID="com.biliwind.blog.admin.windblog_admin_flutter"

EXEC_PATH="${1:-}"
if [[ -z "${EXEC_PATH}" ]]; then
  for candidate in \
    "${APP_DIR}/build/linux/x64/release/bundle/windblog_admin_flutter" \
    "${APP_DIR}/build/linux/x64/debug/bundle/windblog_admin_flutter"
  do
    if [[ -x "${candidate}" ]]; then
      EXEC_PATH="${candidate}"
      break
    fi
  done
fi

if [[ -z "${EXEC_PATH}" ]]; then
  echo "Usage: $0 [/path/to/windblog_admin_flutter]" >&2
  echo "Could not find a built Linux bundle under ${APP_DIR}/build/linux/x64/." >&2
  exit 1
fi

EXEC_PATH="$(realpath "${EXEC_PATH}")"
ICON_SRC="${APP_DIR}/web/icons/Icon-512.png"
TEMPLATE_SRC="${SCRIPT_DIR}/${APP_ID}.desktop.in"

APPS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
ICONS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/hicolor/512x512/apps"

mkdir -p "${APPS_DIR}" "${ICONS_DIR}"
install -m 644 "${ICON_SRC}" "${ICONS_DIR}/${APP_ID}.png"

escaped_exec="${EXEC_PATH//\\/\\\\}"
escaped_exec="${escaped_exec//&/\\&}"
escaped_exec="${escaped_exec//|/\\|}"
sed "s|@WINDBLOG_DESKTOP_EXEC@|${escaped_exec}|g" "${TEMPLATE_SRC}" > "${APPS_DIR}/${APP_ID}.desktop"
chmod 644 "${APPS_DIR}/${APP_ID}.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APPS_DIR}" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${XDG_DATA_HOME:-${HOME}/.local/share}/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Installed ${APP_ID}.desktop -> ${APPS_DIR}/${APP_ID}.desktop (Exec=${EXEC_PATH})"
