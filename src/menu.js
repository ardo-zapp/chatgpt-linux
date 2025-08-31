"use strict";

const { Menu, shell, clipboard, dialog, nativeImage } = require("electron");
const path = require("path");
const fs = require("fs");

/* ========== Util ========== */
function readJSONSafe(p) {
  try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch { return null; }
}
function readTextSafe(p) {
  try { return fs.readFileSync(p, "utf8"); } catch { return null; }
}
function getPkg() {
  const pkgPath = path.join(__dirname, "..", "package.json");
  return readJSONSafe(pkgPath) || {};
}
function getIconImage() {
  const iconPng = path.join(__dirname, "..", "assets", "icons", "png", "favicon.png");
  try {
    if (fs.existsSync(iconPng)) return nativeImage.createFromPath(iconPng);
  } catch {}
  return undefined;
}
function getLicenseText() {
  const licPath = path.join(__dirname, "..", "LICENSE");
  return readTextSafe(licPath);
}

/* ========== Dialog actions ========== */
async function showAbout(win, t) {
  const pkg = getPkg();
  const product = pkg.productName || pkg.name || "App";
  const version = pkg.version ? `v${pkg.version}` : "";
  const author = typeof pkg.author === "string" ? pkg.author : (pkg.author?.name || "");
  const repo = pkg.repository && (typeof pkg.repository === "string" ? pkg.repository : pkg.repository.url || "");
  const icon = getIconImage();

  const lines = [];
  if (version) lines.push(`${t("version") || "Version"}: ${version}`);
  if (author)  lines.push(`${t("developer") || "Developer"}: ${author}`);
  if (repo)    lines.push(`${t("repository") || "Repository"}: ${repo}`);
  lines.push("");
  lines.push(t("disclaimerTitle") || "Disclaimer:");
  lines.push(t("disclaimerText") || "This project is unofficial...");

  await dialog.showMessageBox(win, {
    type: "info",
    title: `${product} ${version}`.trim(),
    message: product,
    detail: lines.join("\n"),
    icon,
    buttons: [t("ok") || "OK"],
    noLink: true,
    normalizeAccessKeys: true,
  });
}

async function showLicense(win, t) {
  const txt = getLicenseText();
  const icon = getIconImage();
  await dialog.showMessageBox(win, {
    type: txt ? "info" : "warning",
    title: t("license") || "License",
    message: t("license") || "License",
    detail: txt || (t("licenseNotFound") || "LICENSE file not found."),
    icon,
    buttons: [t("ok") || "OK"],
    noLink: true,
  });
}

/* ========== Menubar ========== */
function buildTemplate(t) {
  const pkg = getPkg();
  const product = pkg.productName || "ChatGPT";

  return [
    {
      label: product,
      submenu: [
        {
          label: t("about") || "About",
          click: (menuItem, browserWindow) => browserWindow && showAbout(browserWindow, t),
        },
        {
          label: t("license") || "License",
          click: (menuItem, browserWindow) => browserWindow && showLicense(browserWindow, t),
        },
        { type: "separator" },
        { role: "quit", label: t("quit") || "Quit" },
      ],
    },

    {
      label: t("edit") || "Edit",
      submenu: [
        { role: "undo", label: t("undo") || "Undo" },
        { role: "redo", label: t("redo") || "Redo" },
        { type: "separator" },
        { role: "cut", label: t("cut") || "Cut" },
        { role: "copy", label: t("copy") || "Copy" },
        { role: "paste", label: t("paste") || "Paste" },
        { role: "selectAll", label: t("selectAll") || "Select All" },
      ],
    },

    {
      label: t("view") || "View",
      submenu: [
        { label: t("reload") || "Reload", accelerator: "Ctrl+R", click: (_m, bw) => bw && bw.reload() },
        { role: "toggleDevTools", label: t("toggleDevTools") || "Toggle Developer Tools" },
        { type: "separator" },
        { role: "togglefullscreen", label: t("toggleFullscreen") || "Toggle Fullscreen" },
      ],
    },

    {
      label: t("help") || "Help",
      submenu: [
        {
          label: t("openWebsite") || "Open Website",
          click: () => shell.openExternal("https://chatgpt.com"),
        },
        ...(getPkg().repository ? [{
          label: t("reportIssue") || "Report an issue",
          click: () => {
            const repo = getPkg().repository;
            const url = typeof repo === "string" ? repo : (repo.url || "");
            if (url) shell.openExternal(url.replace(/\.git$/, "") + "/issues");
          },
        }] : []),
      ],
    },
  ];
}

function buildMenu(i18n) {
  const { t } = i18n;
  return Menu.buildFromTemplate(buildTemplate(t));
}

/* ========== Right-click Context Menu (window & <webview>) ========== */
function contextTemplateFromParams(t, params) {
  const items = [];
  const hasLink = !!params.linkURL;
  const hasSelection = !!params.selectionText;
  const isEditable = !!params.isEditable;

  if (hasLink) {
    items.push({
      label: t("openLinkInBrowser") || "Open link in browser",
      click: () => shell.openExternal(params.linkURL),
    });
    items.push({
      label: t("copyLinkAddress") || "Copy link address",
      click: () => clipboard.writeText(params.linkURL),
    });
    items.push({ type: "separator" });
  }

  if (isEditable) {
    items.push({ role: "cut", label: t("cut") || "Cut" });
    items.push({ role: "copy", label: t("copy") || "Copy" });
    items.push({ role: "paste", label: t("paste") || "Paste" });
    items.push({ type: "separator" });
  } else if (hasSelection) {
    items.push({ role: "copy", label: t("copy") || "Copy" });
    items.push({ type: "separator" });
  }

  items.push({ role: "selectAll", label: t("selectAll") || "Select All" });

  // Inspect Element
  if (params && params.x != null && params.y != null && params.modifiers?.includes("ctrl")) {
    items.push({ type: "separator" });
    items.push({
      label: t("inspectElement") || "Inspect Element",
      click: (_m, win) => win && win.webContents.inspectElement(params.x, params.y),
    });
  }

  return items;
}

function attachContextMenuToWebContents(wc, i18n) {
  const { t } = i18n;
  if (!wc || typeof wc.on !== "function") return;

  wc.on("context-menu", (_event, params) => {
    const menu = Menu.buildFromTemplate(contextTemplateFromParams(t, params));
    menu.popup({ x: params?.x, y: params?.y });
  });
}

function attachContextMenu(win, i18n) {
  attachContextMenuToWebContents(win.webContents, i18n);
  win.webContents.on("did-attach-webview", (_event, webContents) => {
    attachContextMenuToWebContents(webContents, i18n);
  });
}

module.exports = { buildMenu, attachContextMenu };