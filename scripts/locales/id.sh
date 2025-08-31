say() {
  case "$1" in
    build_start)    printf "[info] Memulai proses build…\n" ;;
    build_done)     printf "[info] Build selesai: %s\n" "${2:-}" ;;
    build_fail)     printf "ERROR: Build gagal.\n" ;;
    preparing)      printf "[info] Menyiapkan direktori tujuan: %s\n" "${2:-}" ;;
    copying)        printf "[info] Menyalin berkas rilis ke %s\n" "${2:-}" ;;
    sandbox_fix)    printf "[info] Mengatur izin chrome-sandbox…\n" ;;
    sandbox_warn)   printf "[warn] chrome-sandbox tidak ditemukan di: %s\n" "${2:-}" ;;
    desktop_entry)  printf "[info] Shortcut desktop terpasang di %s\n" "${2:-}" ;;
    installed)      printf "[info] Instalasi selesai. Jalankan ChatGPT dari menu aplikasi.\n" ;;
    not_root)                       printf "ERROR: Jangan jalankan build sebagai root. Jalankan sebagai user biasa.\n" ;;
    prepare_release)                printf "[info] Menyiapkan direktori rilis: %s\n" "${2:-}" ;;
    removing_sandbox_root_owned)    printf "[info] chrome-sandbox dimiliki root, menghapus: %s\n" "${2:-}" ;;
    removing_old_release_with_sudo) printf "[warn] Gagal menghapus rilis lama tanpa sudo; mencoba dengan sudo: %s\n" "${2:-}" ;;
    packaging_start)                printf "[info] Mem-packing aplikasi untuk Linux x64…\n" ;;
    *)                              printf "[info] %s\n" "$1" ;;
  esac
}
