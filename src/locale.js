"use strict";

const { app } = require("electron");
const path = require("path");
const fs = require("fs");

function detectLang() {
  const cands = [];
  try {
    if (typeof app?.getLocale === "function") cands.push(app.getLocale());
    if (typeof app?.getPreferredSystemLanguages === "function")
      cands.push(...app.getPreferredSystemLanguages());
  } catch {}
  cands.push(process.env.LANG, process.env.LC_ALL, process.env.LC_MESSAGES);
  for (const c of cands) {
    const lc = String(c || "").toLowerCase();
    if (!lc) continue;
    if (lc.startsWith("id") || lc.startsWith("in")) return "id";
    if (lc.startsWith("en")) return "en";
    if (lc.length >= 2) return lc.slice(0, 2);
  }
  return "en";
}

function loadJsonSafe(p) {
  try {
    if (fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {}
  return {};
}

function createI18n() {
  const baseDir = path.join(__dirname, "..", "locales");
  const lang = detectLang();
  const en = loadJsonSafe(path.join(baseDir, "en.json"));
  const picked = loadJsonSafe(path.join(baseDir, `${lang}.json`));
  const dict = { ...en, ...picked };
  const t = (k) => (k in dict ? dict[k] : k);
  return { lang, t };
}

module.exports = { createI18n };
