#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# --- Paths
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

# --- Locales
LOCALE_DIR="${SCRIPT_DIR}/locales"
DESKTOP_LOCALE_FILE="${LOCALE_DIR}/desktop.sh"

# --- Locale helpers (newline-safe; IFS keeps spaces intact)
list_locales() {
  # Emit one code per line; exclude desktop.sh
  [[ -d "$LOCALE_DIR" ]] || { return; }
  ls -1 "$LOCALE_DIR" 2>/dev/null \
    | grep -E '^[a-z]{2}([_-][A-Za-z0-9@.]+)?\.sh$' \
    | sed 's/\.sh$//' \
    | sort -u
}

_read_system_locale() {
  # Ubuntu stores defaults here
  if [[ -r /etc/default/locale ]]; then
    # shellcheck disable=SC1091
    . /etc/default/locale
    local v="${LC_ALL:-${LC_MESSAGES:-${LANG:-${LANGUAGE:-}}}}"
    [[ -n "$v" ]] && { echo "$v"; return; }
  fi
  # systemd fallback
  if command -v localectl >/dev/null 2>&1; then
    local line v
    line="$(localectl status 2>/dev/null | grep -E 'System Locale:|LANG=|LC_MESSAGES=')" || true
    v="$(sed -n 's/.*LC_ALL=\([^[:space:]]*\).*/\1/p; t; s/.*LC_MESSAGES=\([^[:space:]]*\).*/\1/p; t; s/.*LANG=\([^[:space:]]*\).*/\1/p' <<<"$line" | head -n1)"
    [[ -n "$v" ]] && { echo "$v"; return; }
  fi
  echo ""
}

_normalize_lang() {
  local v="$1"
  [[ "$v" == *:* ]] && v="${v%%:*}"  # LANGUAGE can be a colon list; take first
  v="${v%%.*}"                       # strip charset
  printf '%s' "${v,,}"               # lowercase
}

_short_lang() {
  local v="$1"
  local s="${v%%[_-]*}"
  if [[ -z "$s" || "$s" == "$v" && ${#s} -gt 2 ]]; then s="${v:0:2}"; fi
  printf '%s' "$s"
}

_have_locale() {
  # Check membership in newline-delimited list
  local needle="$1"
  while IFS= read -r c; do
    [[ "$c" == "$needle" ]] && return 0
  done < <(list_locales)
  return 1
}

detect_lang_code() {
  local cli="${1:-}" envlang alt short
  # CLI override
  if [[ -n "$cli" ]] && _have_locale "$cli"; then
    echo "$cli"; return
  fi
  # Prefer LC_ALL → LC_MESSAGES → LANG; LANGUAGE last
  envlang="${LC_ALL:-${LC_MESSAGES:-${LANG:-${LANGUAGE:-}}}}"
  # If empty/C/POSIX, read system defaults
  if [[ -z "${envlang:-}" || "${envlang^^}" == "C" || "${envlang^^}" == "POSIX" || "${envlang^^}" == "C.UTF-8" ]]; then
    envlang="$(_read_system_locale)"
  fi
  envlang="$(_normalize_lang "${envlang}")"
  # exact / alt / short
  if _have_locale "$envlang"; then echo "$envlang"; return; fi
  alt="${envlang//-/_}"; if _have_locale "$alt"; then echo "$alt"; return; fi
  short="$(_short_lang "$envlang")"; if _have_locale "$short"; then echo "$short"; return; fi
  echo "en"
}

load_locale() {
  local code; code="$(detect_lang_code "${1:-}")"
  local file="${LOCALE_DIR}/${code}.sh"
  [[ -f "$file" ]] || file="${LOCALE_DIR}/en.sh"
  # shellcheck source=/dev/null
  source "$file"
}

# --- Sudo check
need_sudo() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -v || { echo "sudo authentication failed." >&2; exit 1; }
    else
      echo "sudo required but not found. run as root." >&2
      exit 1
    fi
  fi
}

# --- Build app (always forwards a resolved --lang; mute build.sh debug)
ensure_built() {
  local user_cli_lang="${1:-}"
  local resolved_lang; resolved_lang="$(detect_lang_code "$user_cli_lang")"

  say build_start
  pushd "$ROOT_DIR" >/dev/null
  export START_LANG="$resolved_lang"

  if npm run | grep -qE 'build-linux'; then
    if ! QUIET=1 npm run build-linux -- --lang="${resolved_lang}"; then
      local BUILD_SCRIPT="${ROOT_DIR}/scripts/build.sh"
      if [[ -x "${BUILD_SCRIPT}" ]]; then
        chmod +x "${BUILD_SCRIPT}"
        QUIET=1 bash "${BUILD_SCRIPT}" --lang="${resolved_lang}" || { say build_fail; popd >/dev/null; exit 1; }
      else
        say build_fail; popd >/dev/null; exit 1
      fi
    fi
  else
    local BUILD_SCRIPT="${ROOT_DIR}/scripts/build.sh"
    if [[ -x "${BUILD_SCRIPT}" ]]; then
      chmod +x "${BUILD_SCRIPT}"
      QUIET=1 bash "${BUILD_SCRIPT}" --lang="${resolved_lang}" || { say build_fail; popd >/dev/null; exit 1; }
    else
      say build_fail; popd >/dev/null; exit 1
    fi
  fi

  popd >/dev/null
  [[ -x "${BUILD_BIN}" ]] || { say build_fail; exit 1; }
  say build_done "$BUILD_DIR"
}

# --- Copy packaged app into /opt
prepare_destination() {
  need_sudo
  say preparing "$DEST_DIR"
  [[ -d "${DEST_DIR}" ]] && sudo rm -rf --one-file-system "${DEST_DIR}"
  sudo mkdir -p "${DEST_DIR}"
  say copying "$DEST_DIR"
  sudo cp -a "${BUILD_DIR}/." "${DEST_DIR}/"
}

# --- Fix chrome-sandbox setuid perms
fix_sandbox() {
  if [[ ! -f "${SANDBOX}" ]]; then
    say sandbox_warn "$SANDBOX"; return
  fi
  say sandbox_fix
  sudo chown root:root "${SANDBOX}"
  sudo chmod 4755 "${SANDBOX}"
}

# --- Append localized Comment= lines to .desktop
append_desktop_comments() {
  local out="$1"
  if [[ -f "${DESKTOP_LOCALE_FILE}" ]]; then
    awk 'BEGIN{IGNORECASE=0}
         /^[[:space:]]*Comment(\[[^]]+\])?[[:space:]]*=/ {print}' \
         "${DESKTOP_LOCALE_FILE}" >> "${out}"
  else
    cat >> "${out}" <<'EOF_COMMENTS'
Comment=Simple and efficient desktop client for ChatGPT.
EOF_COMMENTS
  fi
}

# --- Install .desktop system-wide
# Note: if install.sh was run with --lang=XX, include it in TryExec/Exec.
install_desktop_entry_global() {
  local desktop_tmp; desktop_tmp="$(mktemp)"
  local exec_cmd="${DEST_DIR}/${APP_NAME}"
  local tryexec_cmd="${DEST_DIR}/${APP_NAME}"

  # If --lang= was provided to install.sh, propagate only to Exec
  if [[ -n "${lang_arg:-}" ]]; then
    exec_cmd="$exec_cmd --lang=${lang_arg}"
    # tryexec_cmd stays without args (spec requirement)
  fi

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
TryExec=${tryexec_cmd}
Exec=${exec_cmd} %U
EOF
  append_desktop_comments "${desktop_tmp}"

  need_sudo
  sudo install -m 644 "${desktop_tmp}" "${DESKTOP_PATH}"
  rm -f "${desktop_tmp}"

  command -v update-desktop-database >/dev/null 2>&1 && sudo update-desktop-database /usr/share/applications || true
  command -v xdg-desktop-menu >/dev/null 2>&1 && xdg-desktop-menu forceupdate || true
  say desktop_entry "${DESKTOP_PATH}"
}

# --- Main
# Keep lang_arg at file scope so other funcs (desktop entry) can read it.
lang_arg=""
main() {
  # Accept --lang= from any position
  for arg in "$@"; do
    [[ "$arg" == --lang=* ]] && { lang_arg="${arg#--lang=}"; break; }
  done

  load_locale "$lang_arg"
  ensure_built "$lang_arg"
  prepare_destination
  fix_sandbox
  install_desktop_entry_global
  say installed
}
main "$@"
