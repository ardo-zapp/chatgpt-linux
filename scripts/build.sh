#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="ChatGPT"
OUT_DIR="${ROOT_DIR}/release-builds/${APP_NAME}-linux-x64"
SANDBOX="${OUT_DIR}/chrome-sandbox"
LOCALE_DIR="${SCRIPT_DIR}/locales"

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

main() {
  # accept --lang from any position (e.g. forwarded by install-linux.sh)
  local lang_arg=""
  for arg in "$@"; do
    [[ "$arg" =~ ^--lang=.+$ ]] && { lang_arg="${arg#--lang=}"; break; }
  done

  load_locale "$lang_arg"

  # refuse running as root
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    say not_root
    exit 1
  fi

  say prepare_release "$OUT_DIR"

  # clean old build
  if [[ -d "$OUT_DIR" ]]; then
    if [[ -e "$SANDBOX" ]]; then
      owner="$(stat -c '%u' "$SANDBOX" 2>/dev/null || echo "")"
      [[ "$owner" == "0" ]] && { say removing_sandbox_root_owned "$SANDBOX"; sudo rm -f "$SANDBOX"; }
    fi
    rm -rf "$OUT_DIR" 2>/dev/null || { say removing_old_release_with_sudo "$OUT_DIR"; sudo rm -rf "$OUT_DIR"; }
  fi

  say packaging_start
  pushd "$ROOT_DIR" >/dev/null

  # exclude /scripts from packaged app
  npx electron-packager . \
    --overwrite \
    --platform=linux \
    --arch=x64 \
    --icon=assets/icons/png/favicon.png \
    --out=release-builds \
    --ignore="(^|[/\\\\])scripts($|[/\\\\])"

  popd >/dev/null

  # fix chrome-sandbox perms for chromium sandbox
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
