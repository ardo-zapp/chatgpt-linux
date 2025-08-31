"use strict";

const path = require("path");
const { BrowserWindow } = require("electron");

function createBrowserWindow() {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    autoHideMenuBar: true,
    //backgroundColor: "#121212",
    webPreferences: {
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
      enableRemoteModule: false,
      spellcheck: true,
      preload: path.join(__dirname, "..", "preload.js"),
      webviewTag: true,
    },
  });

  win.on("ready-to-show", () => win.show());
  return win;
}

module.exports = { createBrowserWindow };
