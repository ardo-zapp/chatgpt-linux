"use strict";

const os = require("os");
const fs = require("fs");
const path = require("path");
const { spawn, spawnSync } = require("child_process");

const ROOT = __dirname;
const isLinux = os.platform() === "linux";
const LOCALES_DIR = path.join(ROOT, "locales");

/* ===== i18n loader (scan /locales) ===== */
function listLocales(dir) {
  try {
    return fs
      .readdirSync(dir, { withFileTypes: true })
      .filter((d) => d.isFile() && d.name.toLowerCase().endsWith(".json"))
      .map((d) => path.basename(d.name, ".json"));
  } catch {
    return [];
  }
}
function loadLocales(dir) {
  const map = {};
  for (const code of listLocales(dir)) {
    const p = path.join(dir, `${code}.json`);
    try {
      map[code] = JSON.parse(fs.readFileSync(p, "utf8"));
    } catch {}
  }
  return map;
}
function detectLang(available) {
  const envPref =
    process.argv.find((a) => a.startsWith("--lang="))?.split("=")[1] ||
    process.env.npm_config_lang || // npm start --lang=xx
    process.env.START_LANG ||
    process.env.APP_LANG ||
    process.env.LANG ||
    "en";
  const lc = String(envPref).toLowerCase().split(".")[0];
  if (available.includes(lc)) return lc;
  const short = lc.split(/[-_]/)[0];
  if (available.includes(short)) return short;
  if (available.includes("en")) return "en";
  return available[0] || "en";
}
function makeI18n(dir) {
  const dicts = loadLocales(dir);
  const available = Object.keys(dicts).sort();
  const current = detectLang(available);
  function t(key, vars) {
    const str = dicts[current]?.[key] ?? dicts["en"]?.[key] ?? key;
    if (!vars) return str;
    return Object.keys(vars).reduce(
      (s, k) => s.replaceAll(`{${k}}`, String(vars[k])),
      String(str)
    );
  }
  return { t, current, available, dicts };
}

/* ===== Electron path & sandbox helpers ===== */
function resolveElectronPaths() {
  let electronPath = require("electron");
  if (typeof electronPath !== "string") {
    try {
      const binGuess = path.resolve(ROOT, "node_modules", ".bin", "electron");
      if (fs.existsSync(binGuess)) electronPath = binGuess;
    } catch {}
  }
  const electronModuleDir = path.dirname(require.resolve("electron"));
  const chromeSandbox = path.join(electronModuleDir, "dist", "chrome-sandbox");
  return { electronPath, chromeSandbox };
}
function isSandboxFixed(p) {
  try {
    const st = fs.statSync(p);
    return (
      st.uid === 0 &&
      (st.mode & 0o4000) === 0o4000 &&
      (st.mode & 0o0001) === 0o0001
    );
  } catch {
    return false;
  }
}
function shSync(cmd) {
  const out = spawnSync("/bin/sh", ["-lc", cmd], {
    stdio: ["ignore", "pipe", "pipe"],
    env: process.env,
  });
  return {
    ok: out.status === 0,
    code: out.status,
    stdout: out.stdout?.toString() || "",
    stderr: out.stderr?.toString() || "",
  };
}
function shInteractive(cmd) {
  return new Promise((resolve) => {
    const p = spawn("/bin/sh", ["-lc", cmd], {
      stdio: "inherit",
      env: process.env,
    });
    p.on("exit", (code, sig) => resolve({ ok: code === 0 && !sig, code, sig }));
    p.on("error", () => resolve({ ok: false, code: 1 }));
  });
}
async function tryFixSandbox(p, t) {
  try {
    if (!fs.existsSync(p)) return false;
    if (isSandboxFixed(p)) return true;
    if (typeof process.getuid === "function" && process.getuid() === 0) {
      fs.chownSync(p, 0, 0);
      fs.chmodSync(p, 0o4755);
      return isSandboxFixed(p);
    }
    const rNon = shSync(
      `sudo -n chown root:root "${p}" && sudo -n chmod 4755 "${p}"`
    );
    if (rNon.ok && isSandboxFixed(p)) return true;
    console.log(t("sudo_prompt"));
    const r = await shInteractive(
      `sudo /bin/sh -lc 'chown root:root "${p}" && chmod 4755 "${p}"'`
    );
    if (r.ok && isSandboxFixed(p)) return true;
    return false;
  } catch {
    return false;
  }
}
function printManualInstructions(p, t) {
  console.log("");
  console.log(t("howto_header"));
  console.log(`  ${t("howto_line1", { path: p })}`);
  console.log(`  ${t("howto_line2", { path: p })}`);
  console.log("");
  console.log(t("howto_note"));
  console.log("");
}

/* ===== Launch Electron, propagate language ===== */
function launchElectron(
  electronPath,
  extraArgs,
  withNoSandbox,
  t,
  currentLang
) {
  const args = ["."].concat(extraArgs || []);
  const hasLangArg = args.some((a) => String(a).startsWith("--lang="));
  if (!hasLangArg && currentLang) args.unshift(`--lang=${currentLang}`);
  if (withNoSandbox) {
    if (!args.includes("--no-sandbox")) args.unshift("--no-sandbox");
    process.env.ELECTRON_DISABLE_SANDBOX = "1";
  }
  const childEnv = { ...process.env };
  if (currentLang) childEnv.APP_LANG = currentLang;
  console.info(t("launching", { bin: electronPath, args: args.join(" ") }));
  const child = spawn(electronPath, args, { stdio: "inherit", env: childEnv });
  child.on("exit", (code, signal) => {
    if (signal) process.exit(1);
    else process.exit(code ?? 0);
  });
}

/* ===== Main ===== */
(async function main() {
  const { t, current } = makeI18n(LOCALES_DIR);
  const extraArgs = process.argv.slice(2);
  const { electronPath, chromeSandbox } = resolveElectronPaths();

  if (!electronPath || !fs.existsSync(electronPath)) {
    console.error(t("electron_not_found"));
    process.exit(1);
  }

  if (!isLinux) {
    launchElectron(electronPath, extraArgs, false, t, current);
    return;
  }

  console.log(t("checking_sandbox"));
  const fixed = await tryFixSandbox(chromeSandbox, t);
  if (fixed) {
    console.log(t("sandbox_ok"));
    launchElectron(electronPath, extraArgs, false, t, current);
    return;
  }

  console.warn(t("sandbox_not_fixed"));
  printManualInstructions(chromeSandbox, t);
  console.warn(t("fallback_warn"));
  launchElectron(electronPath, extraArgs, true, t, current);
})();
