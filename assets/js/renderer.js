"use strict";

document.addEventListener("DOMContentLoaded", async () => {
  const wv = document.getElementById("webview");
  if (!wv) return;

  try {
    const ua = (await window.electron.getUserAgent()) || navigator.userAgent;
    wv.addEventListener("dom-ready", async () => {
      try {
        const currentUrl = await wv.getURL();
        if (typeof currentUrl === "string" && currentUrl.startsWith("http")) {
          if (!wv.hasAttribute("data-ua-applied")) {
            wv.setAttribute("data-ua-applied", "1");
            wv.loadURL(currentUrl, { userAgent: ua });
          }
        }
      } catch {}
    });
  } catch {}
});

document.addEventListener("DOMContentLoaded", () => {
  const wv = document.getElementById("webview");
  if (!wv) return;
  wv.setAttribute("tabindex", "0");
  wv.addEventListener("dom-ready", () => {
    try {
      if (typeof wv.focus === "function") wv.focus();
    } catch {}
  });
});
