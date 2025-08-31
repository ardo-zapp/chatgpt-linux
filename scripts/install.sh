#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="ChatGPT"
BUILD_DIR="${ROOT_DIR}/release-builds/${APP_NAME}-linux-x64"
BUILD_BIN="${BUILD_DIR}/${APP_NAME}"

DEST_DIR="/opt/jacktor/chatgpt"
SANDBOX="${DEST_DIR}/chrome-sandbox"

DESKTOP_DIR="/usr/share/applications"
DESKTOP_PATH="${DESKTOP_DIR}/chatgpt.desktop"
ICON_PATH="${DEST_DIR}/resources/app/assets/icons/png/favicon.png"

# locales
LOCALE_DIR="${SCRIPT_DIR}/locales"
DESKTOP_LOCALE_FILE="${LOCALE_DIR}/desktop.sh"

# locale helpers
list_locales() { [[ -d "$LOCALE_DIR" ]] || { echo ""; return; }; ls -1 "$LOCALE_DIR" 2>/dev/null | awk -F. '/\.sh$/ {print $1}' | sort -u | tr '\n' ' '; }
detect_lang_code() {
  local cli="${1:-}"; local avail; avail="$(list_locales)"; local pick=""
  if [[ -n "$cli" ]]; then for c in $avail; do [[ "$c" == "$cli" ]] && pick="$c"; done; [[ -n "$pick" ]] && { echo "$pick"; return; }; fi
  local envlang="${npm_config_lang:-${START_LANG:-${APP_LANG:-${LANG:-en}}}}"
  envlang="${envlang%%.*}"; envlang="${envlang,,}"
  for c in $avail; do [[ "$c" == "$envlang" ]] && pick="$c"; done; [[ -n "$pick" ]] && { echo "$pick"; return; }
  local short="${envlang%%[_-]*}"; for c in $avail; do [[ "$c" == "$short" ]] && pick="$c"; done; [[ -n "$pick" ]] && { echo "$pick"; return; }
  echo "en"
}
load_locale() { local code; code="$(detect_lang_code "${1:-}")"; local file="${LOCALE_DIR}/${code}.sh"; [[ -f "$file" ]] || file="${LOCALE_DIR}/en.sh"; source "$file"; }

# sudo check
need_sudo() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then sudo -v || { echo "sudo authentication failed."; exit 1; }
    else echo "sudo required but not found. run as root."; exit 1; fi
  fi
}

# build app (forwards --lang if provided)
ensure_built() {
  local lang="${1:-}"
  say build_start
  pushd "$ROOT_DIR" >/dev/null
  if ! npm run build-linux -- --lang="${lang}"; then
    local BUILD_SCRIPT="${ROOT_DIR}/scripts/build.sh"
    if [[ -x "${BUILD_SCRIPT}" ]]; then
      chmod +x "${BUILD_SCRIPT}"
      bash "${BUILD_SCRIPT}" --lang="${lang}" || { say build_fail; popd >/dev/null; exit 1; }
    else
      say build_fail; popd >/dev/null; exit 1
    fi
  fi
  popd >/dev/null
  [[ -x "${BUILD_BIN}" ]] || { say build_fail; exit 1; }
  say build_done "$BUILD_DIR"
}

# copy to /opt
prepare_destination() {
  need_sudo
  say preparing "$DEST_DIR"
  [[ -d "${DEST_DIR}" ]] && sudo rm -rf --one-file-system "${DEST_DIR}"
  sudo mkdir -p "${DEST_DIR}"
  say copying "$DEST_DIR"
  sudo cp -a "${BUILD_DIR}/." "${DEST_DIR}/"
}

# setuid sandbox
fix_sandbox() {
  if [[ ! -f "${SANDBOX}" ]]; then say sandbox_warn "$SANDBOX"; return; fi
  say sandbox_fix
  sudo chown root:root "${SANDBOX}"
  sudo chmod 4755 "${SANDBOX}"
}

# append localized Comment= lines to .desktop
append_desktop_comments() {
  local out="$1"
  if [[ -f "${DESKTOP_LOCALE_FILE}" ]]; then
    awk 'BEGIN{IGNORECASE=0}
         /^[[:space:]]*Comment(\[[^]]+\])?[[:space:]]*=/ {print}' \
         "${DESKTOP_LOCALE_FILE}" >> "${out}"
  else
    cat >> "${out}" <<'EOF_COMMENTS'
Comment=Simple and efficient desktop client for ChatGPT.
Comment[id]=Klien desktop yang sederhana dan efisien untuk ChatGPT.
EOF_COMMENTS
  fi
}

# install .desktop system-wide
install_desktop_entry_global() {
  local desktop_tmp; desktop_tmp="$(mktemp)"
  cat > "${desktop_tmp}" <<EOF
[Desktop Entry]
Type=Application
Name=ChatGPT
Icon=${ICON_PATH}
Categories=Utility;
StartupNotify=true
StartupWMClass=ChatGPT
NoDisplay=false
Terminal=false
TryExec=${DEST_DIR}/${APP_NAME}
Exec=${DEST_DIR}/${APP_NAME} %U
EOF
  append_desktop_comments "${desktop_tmp}"

  need_sudo
  sudo install -m 644 "${desktop_tmp}" "${DESKTOP_PATH}"
  rm -f "${desktop_tmp}"

  command -v update-desktop-database >/dev/null 2>&1 && sudo update-desktop-database /usr/share/applications || true
  command -v xdg-desktop-menu >/dev/null 2>&1 && xdg-desktop-menu forceupdate || true
  say desktop_entry "${DESKTOP_PATH}"
}

main() {
  # accept --lang from any position
  local lang_arg=""; for arg in "$@"; do [[ "$arg" =~ ^--lang=.+$ ]] && { lang_arg="${arg#--lang=}"; break; }; done
  load_locale "$lang_arg"
  ensure_built "$lang_arg"
  prepare_destination
  fix_sandbox
  install_desktop_entry_global
  say installed
}
main "$@"
