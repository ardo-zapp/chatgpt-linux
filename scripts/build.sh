#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Debug printer; muted when QUIET=1
dbg() { [[ "${QUIET:-0}" = "1" ]] && return; echo "$@" >&2; }

dbg "[debug] using script: $0"

# --- Paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="ChatGPT"
OUT_DIR="${ROOT_DIR}/release-builds/${APP_NAME}-linux-x64"
SANDBOX="${OUT_DIR}/chrome-sandbox"
LOCALE_DIR="${SCRIPT_DIR}/locales"

# --- Locale helpers
list_locales() {
  [[ -d "$LOCALE_DIR" ]] || { return; }
  ls -1 "$LOCALE_DIR" 2>/dev/null \
    | grep -E '^[a-z]{2}([_-][A-Za-z0-9@.]+)?\.sh$' \
    | sed 's/\.sh$//' \
    | sort -u
}

_read_system_locale() {
  if [[ -r /etc/default/locale ]]; then
    # shellcheck disable=SC1091
    . /etc/default/locale
    local v="${LC_ALL:-${LC_MESSAGES:-${LANG:-${LANGUAGE:-}}}}"
    [[ -n "$v" ]] && { echo "$v"; return; }
  fi
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
  [[ "$v" == *:* ]] && v="${v%%:*}"
  v="${v%%.*}"
  printf '%s' "${v,,}"
}

_short_lang() {
  local v="$1"
  local s="${v%%[_-]*}"
  if [[ -z "$s" || "$s" == "$v" && ${#s} -gt 2 ]]; then s="${v:0:2}"; fi
  printf '%s' "$s"
}

_have_locale() {
  local needle="$1"
  while IFS= read -r c; do
    [[ "$c" == "$needle" ]] && return 0
  done < <(list_locales)
  return 1
}

detect_lang_code() {
  local cli="${1:-}" envlang alt short
  dbg "[debug] LOCALE_DIR=$LOCALE_DIR"
  {
    printf "[debug] available locales:"
    while IFS= read -r c; do printf " %s" "$c"; done < <(list_locales)
    printf "\n"
  } | dbg "$(cat)"
  dbg "[debug] env: LANG=${LANG-} LANGUAGE=${LANGUAGE-} LC_ALL=${LC_ALL-} LC_MESSAGES=${LC_MESSAGES-}"

  # CLI override
  if [[ -n "$cli" ]] && _have_locale "$cli"; then
    dbg "[debug] resolved locale: $cli (cli)"
    echo "$cli"; return
  fi

  # LC_ALL → LC_MESSAGES → LANG → LANGUAGE
  envlang="${LC_ALL:-${LC_MESSAGES:-${LANG:-${LANGUAGE:-}}}}"
  if [[ -z "${envlang:-}" || "${envlang^^}" == "C" || "${envlang^^}" == "POSIX" || "${envlang^^}" == "C.UTF-8" ]]; then
    envlang="$(_read_system_locale)"
  fi
  envlang="$(_normalize_lang "${envlang}")"
  dbg "[debug] normalized: ${envlang:-<empty>}"

  # exact / alt / short
  if _have_locale "$envlang"; then dbg "[debug] resolved locale: $envlang (exact)"; echo "$envlang"; return; fi
  alt="${envlang//-/_}"; if _have_locale "$alt"; then dbg "[debug] resolved locale: $alt (alt)"; echo "$alt"; return; fi
  short="$(_short_lang "$envlang")"; if _have_locale "$short"; then dbg "[debug] resolved locale: $short (short)"; echo "$short"; return; fi

  dbg "[debug] resolved locale: en (fallback)"
  echo "en"
}

load_locale() {
  local code; code="$(detect_lang_code "${1:-}")"
  local file="${LOCALE_DIR}/${code}.sh"
  dbg "[debug] loading: $file"
  [[ -f "$file" ]] || file="${LOCALE_DIR}/en.sh"
  # shellcheck source=/dev/null
  source "$file"
  [[ "$(type -t say || true)" == "function" ]] || dbg "[debug] warn: say() not found in $file"
}

main() {
  # Accept --lang=... (optional)
  local lang_arg=""
  for arg in "$@"; do
    [[ "$arg" == --lang=* ]] && { lang_arg="${arg#--lang=}"; break; }
  done

  load_locale "$lang_arg"

  # Show a quick ping only when not quiet
  if [[ "${QUIET:-0}" != "1" ]]; then
    say prepare_release "/tmp/preview"
  fi

  # Avoid running as root
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    say not_root
    exit 1
  fi

  say prepare_release "$OUT_DIR"

  # Clean old build; remove root-owned chrome-sandbox if present
  if [[ -d "$OUT_DIR" ]]; then
    if [[ -e "$SANDBOX" ]]; then
      owner="$(stat -c '%u' "$SANDBOX" 2>/dev/null || echo "")"
      [[ "$owner" == "0" ]] && { say removing_sandbox_root_owned "$SANDBOX"; sudo rm -f "$SANDBOX"; }
    fi
    rm -rf "$OUT_DIR" 2>/dev/null || { say removing_old_release_with_sudo "$OUT_DIR"; sudo rm -rf "$OUT_DIR"; }
  fi

  say packaging_start
  pushd "$ROOT_DIR" >/dev/null

  npx electron-packager . \
    --overwrite \
    --platform=linux \
    --arch=x64 \
    --icon=assets/icons/png/favicon.png \
    --out=release-builds \
    --ignore="(^|[/\\\\])scripts($|[/\\\\])"

  popd >/dev/null

  if [[ -e "$SANDBOX" ]]; then
    sudo chown root:root "$SANDBOX"
    sudo chmod 4755 "$SANDBOX"
    command -v stat >/dev/null 2>&1 && stat -c '[info] chrome-sandbox: %U:%G %A (%a)' "$SANDBOX" || true
  else
    echo "[warn] chrome-sandbox not found: $SANDBOX"
  fi

  say build_done "$OUT_DIR"
}
main "$@"
