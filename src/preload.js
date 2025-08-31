"use strict";

const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electron", {
  print: (arg) => ipcRenderer.invoke("print", arg),
  openExternal: (url) => ipcRenderer.invoke("open-external", url),
  getUserAgent: async () => ipcRenderer.invoke("get-user-agent"),
});
