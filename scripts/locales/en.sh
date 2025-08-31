say() {
  case "$1" in
    build_start)    printf "[info] Starting build…\n" ;;
    build_done)     printf "[info] Build finished: %s\n" "${2:-}" ;;
    build_fail)     printf "ERROR: Build failed.\n" ;;
    preparing)      printf "[info] Preparing destination: %s\n" "${2:-}" ;;
    copying)        printf "[info] Copying release to %s\n" "${2:-}" ;;
    sandbox_fix)    printf "[info] Setting chrome-sandbox permissions…\n" ;;
    sandbox_warn)   printf "[warn] chrome-sandbox not found at: %s\n" "${2:-}" ;;
    desktop_entry)  printf "[info] Desktop entry installed at %s\n" "${2:-}" ;;
    installed)      printf "[info] Installation completed. Launch ChatGPT from your applications menu.\n" ;;
    not_root)                       printf "ERROR: Do not run the build as root. Run as a regular user.\n" ;;
    prepare_release)                printf "[info] Preparing release output directory: %s\n" "${2:-}" ;;
    removing_sandbox_root_owned)    printf "[info] chrome-sandbox is owned by root, removing: %s\n" "${2:-}" ;;
    removing_old_release_with_sudo) printf "[warn] Failed to remove old release without sudo; retrying with sudo: %s\n" "${2:-}" ;;
    packaging_start)                printf "[info] Packaging app for Linux x64…\n" ;;
    *)                              printf "[info] %s\n" "$1" ;;
  esac
}
