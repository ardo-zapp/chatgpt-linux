"use strict";

const { app, BrowserWindow, session, Menu } = require("electron");
const path = require("path");
const fs = require("fs");

const ROOT = __dirname;
const LOCALES_DIR = path.join(ROOT, "locales");

/* ========== i18n: scan /locales and translate ========== */
function listLocales(localesDir) {
  try {
    return fs
      .readdirSync(localesDir, { withFileTypes: true })
      .filter((d) => d.isFile() && d.name.toLowerCase().endsWith(".json"))
      .map((d) => path.basename(d.name, ".json"));
  } catch {
    return [];
  }
}

function loadLocales(localesDir) {
  const map = {};
  for (const code of listLocales(localesDir)) {
    const p = path.join(localesDir, `${code}.json`);
    try {
      map[code] = JSON.parse(fs.readFileSync(p, "utf8"));
    } catch {
      /* ignore invalid locale file */
    }
  }
  return map;
}

function detectLang(available) {
  const envPref =
    (process.argv.find((a) => a.startsWith("--lang="))?.split("=")[1]) ||
    process.env.npm_config_lang || // npm start --lang=xx
    process.env.APP_LANG ||        // propagated by start.js
    process.env.LANG ||
    "en";

  const lc = String(envPref).toLowerCase().split(".")[0];
  if (available.includes(lc)) return lc;

  const short = lc.split(/[-_]/)[0];
  if (available.includes(short)) return short;

  if (available.includes("en")) return "en";
  return available[0] || "en";
}

function makeI18n(localesDir) {
  const dicts = loadLocales(localesDir);
  const available = Object.keys(dicts).sort();
  const current = detectLang(available);

  function t(key, vars) {
    const str =
      (dicts[current] && dicts[current][key]) ||
      (dicts["en"] && dicts["en"][key]) ||
      key;
    if (!vars) return str;
    return Object.keys(vars).reduce(
      (s, k) => s.replaceAll(`{${k}}`, String(vars[k])),
      String(str)
    );
  }

  return { t, current, available, dicts };
}

/* ========== Chromium language helpers ========== */
function toLanguageTag(lang) {
  const lc = String(lang).trim().replace("_", "-").toLowerCase();
  const map = {
    "zh-cn": "zh-CN",
    "zh-tw": "zh-TW",
    "pt-br": "pt-BR",
    "pt-pt": "pt-PT",
    "en-us": "en-US",
    "en-gb": "en-GB",
    "id": "id", // Indonesian
    "in": "id", // legacy alias
    "he": "he", // modern alias for iw
    "iw": "he",
    "ji": "yi",
    "jw": "jv",
  };
  if (map[lc]) return map[lc];
  if (lc.includes("-")) {
    const [l, r] = lc.split("-");
    return `${l.toLowerCase()}-${r.toUpperCase()}`;
  }
  return lc;
}

function toAcceptLanguageHeader(primary) {
  const tag = toLanguageTag(primary);
  const base = tag.split("-")[0];
  return [tag, base, "en"].filter(Boolean).join(",") + ";q=0.9";
}

/* ========== Clipboard permissions for ChatGPT domains ========== */
const TRUSTED_HOSTS = new Set([
  "chatgpt.com",
  "www.chatgpt.com",
  "chat.openai.com",
  "openai.com",
  "auth.openai.com",
  "platform.openai.com",
]);
const getHost = (u) => {
  try {
    return new URL(u).hostname;
  } catch {
    return "";
  }
};

/* ========== Apply language early ========== */
const AVAILABLE_LOCALES = listLocales(LOCALES_DIR);
const APP_LANG = detectLang(AVAILABLE_LOCALES);
const CHROMIUM_LANG = toLanguageTag(APP_LANG);

app.commandLine.appendSwitch("lang", CHROMIUM_LANG);

/* ========== Create window, load UI, menus and context menu ========== */
function createWindow(i18n) {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
      preload: path.join(ROOT, "preload.js"),
      webviewTag: true,
      spellcheck: true,
    },
  });

  const ses = session.defaultSession;

  // Force Accept-Language header
  try {
    const acceptLang = toAcceptLanguageHeader(CHROMIUM_LANG);
    ses.webRequest.onBeforeSendHeaders((details, callback) => {
      const headers = Object.assign({}, details.requestHeaders);
      headers["Accept-Language"] = acceptLang;
      callback({ cancel: false, requestHeaders: headers });
    });
  } catch {}

  // Spellchecker languages
  try {
    const base = CHROMIUM_LANG.split("-")[0];
    if (typeof ses.setSpellCheckerLanguages === "function") {
      const langs = Array.from(new Set([CHROMIUM_LANG, base, "en-US"]));
      ses.setSpellCheckerLanguages(langs);
    }
  } catch {}

  // Clipboard permission handlers
  ses.setPermissionRequestHandler((wc, permission, callback, details) => {
    const host = getHost(details?.requestingUrl || wc?.getURL?.() || "");
    const ok =
      TRUSTED_HOSTS.has(host) &&
      (permission === "clipboard-read" ||
        permission === "clipboard-write" ||
        permission === "clipboard-sanitized-write");
    callback(!!ok);
  });
  if (typeof ses.setPermissionCheckHandler === "function") {
    ses.setPermissionCheckHandler((_wc, permission, _origin, details) => {
      const host = getHost(details?.requestingUrl || details?.embeddingOrigin || "");
      return (
        TRUSTED_HOSTS.has(host) &&
        (permission === "clipboard-read" ||
          permission === "clipboard-write" ||
          permission === "clipboard-sanitized-write")
      );
    });
  }

  win.loadFile(path.join(ROOT, "html", "index.html"));

  const menuMod = require("./src/menu");
  const menu = menuMod.buildMenu(i18n);
  Menu.setApplicationMenu(menu);
  menuMod.attachContextMenu(win, i18n);

  return win;
}

/* ========== App lifecycle ========== */
let mainWindow = null;

app.whenReady().then(() => {
  const i18n = makeI18n(LOCALES_DIR);
  process.env.APP_LANG = APP_LANG; // propagate
  mainWindow = createWindow(i18n);

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      mainWindow = createWindow(i18n);
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});