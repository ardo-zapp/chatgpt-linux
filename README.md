<p align="center">
  <img width="180" src="./assets/icons/png/favicon.png" alt="ChatGPT">
  <h1 align="center">ChatGPT</h1>
  <p align="center">ChatGPT Desktop Application (Linux)</p>
</p>

![License](https://img.shields.io/badge/License-MIT-green.svg)
[![ChatGPT downloads](https://img.shields.io/github/downloads/ardo-zapp/chatgpt-linux/total.svg?style=flat-square)](https://github.com/ardo-zapp/chatgpt-linux/releases)

A simple desktop client for [ChatGPT](https://chatgpt.com/) built with Electron, targeting **Linux** only.

---

## Disclaimer

This project is **unofficial** and not affiliated with, endorsed by, or connected to OpenAI in any way.  
It exists because there is no official ChatGPT desktop app for Linux.

All trademarks, product names, and company names or logos are the property of their respective owners.  
Use of “ChatGPT” is for descriptive purposes only.

---

## Features (what this app actually does)

- Minimal Electron wrapper around the ChatGPT web experience.
- **Language control**: pass `--lang=<code>` to set Chromium UI language, `Accept-Language` header, and spellchecker.
- **Localization (i18n)** for app menus/dialogs via JSON files in `./locales/`.
- Optional system-wide install to `/opt/jacktor/chatgpt` with a `.desktop` entry.

_(No extra features are added to the ChatGPT website itself — this app focuses on being a lightweight, consistent desktop wrapper.)_

---

## Prerequisites

- Node.js (LTS recommended) and npm
- Linux x64

Clone and install dependencies:

```bash
git clone https://github.com/ardo-zapp/chatgpt-linux.git
cd chatgpt-linux
npm install
```

---

## Run from Source

```bash
npm start
```

### Choose UI Language (optional)

You can override the UI language with `--lang=`:

```bash
# English
npm start -- --lang=en

# Indonesian
npm start -- --lang=id
```

If omitted, the app uses its default language (or system language when supported).

---

## Build & Install (system-wide)

Build the Linux x64 release and install to **/opt/jacktor/chatgpt** with a desktop entry:

```bash
npm run install-linux
```

This will:

- Build the Linux x64 release
- Remove any existing `/opt/jacktor/chatgpt`
- Copy the latest build to `/opt/jacktor/chatgpt`
- Fix `chrome-sandbox` permissions (setuid root)
- Create a desktop entry at `/usr/share/applications/chatgpt.desktop`

After installation, launch **ChatGPT** from your Application Menu (Utility category) or run:

```bash
/opt/jacktor/chatgpt/ChatGPT
```

> You can also pass a language code to the installed binary:
>
> ```bash
> /opt/jacktor/chatgpt/ChatGPT --lang=id
> ```

---

## Build Only (no install)

Generate the release build without installing system-wide:

```bash
npm run build-linux
```

The build output will be located at:

```
release-builds/ChatGPT-linux-x64/
```

### Run the built binary with a language (optional)

```bash
cd release-builds/ChatGPT-linux-x64/
./ChatGPT --lang=id     # or --lang=en
```

---

## Localization (i18n)

This project uses JSON files for translations in **two places**:

1. **App UI strings** → `./locales/`
2. **Scripts / CLI messages** (e.g., installer) → `./scripts/locales/`

Each language file is named by **BCP-47 code** (e.g., `en`, `id`).

### Current structure

```
locales/
  en.json
  id.json

scripts/locales/
  en.json
  id.json
```

> The app picks the language via `--lang=…`. If not provided, it falls back to the default language.

### Add a new language

1. **Copy an existing locale**:

   - Duplicate `locales/en.json` to `locales/<your_lang>.json`
   - Duplicate `scripts/locales/en.json` to `scripts/locales/<your_lang>.json`

2. **Translate the values** in both files. Keep **all keys** unchanged.

3. **Test from source**:

   ```bash
   npm start -- --lang=<your_lang>
   ```

4. **Test the built app** (optional):
   ```bash
   npm run build-linux
   ./release-builds/ChatGPT-linux-x64/ChatGPT --lang=<your_lang>
   ```

> Notes:
>
> - Keys must remain identical across all language files to avoid missing strings.
> - If a key is missing in the selected language, the app may fall back to English (or show the raw key).

---

## Menu & About dialog

- The **About** item includes:
  - App icon
  - Developer / project information
  - License text loaded from `./LICENSE` (if present)

You can customize these via the menu and about handlers in your Electron codebase.

---

## Uninstall (system-wide install)

If you used the system-wide installer, remove the files with:

```bash
sudo rm -rf /opt/jacktor/chatgpt
sudo rm -f /usr/share/applications/chatgpt.desktop
```

---

## Reset User Data (optional)

User data and cache are stored in your home directory. Delete them to reset app state:

```bash
rm -rf ~/.config/ChatGPT
rm -rf ~/.cache/ChatGPT
```

---

## Troubleshooting

- **Blank window**  
  Try launching with `--disable-gpu` or run from a terminal to inspect logs.

- **Wrong language or untranslated strings**  
  Verify the `--lang=` code and ensure both `locales/` and `scripts/locales/` have the same keys.

- **Sandbox permission issues** after install  
  Ensure the installer set `setuid` correctly on `chrome-sandbox`. Re-run `npm run install-linux` with `sudo`.

---

## Contributing

PRs are welcome! Please keep locales in sync across `locales/` and `scripts/locales/`.  
For new features, consider adding keys to all languages (use English as the baseline).

---

## License

MIT — see [LICENSE](./LICENSE).
