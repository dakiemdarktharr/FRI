const { contextBridge, ipcRenderer } = require('electron');
const argument = name => process.argv.find(a => a.startsWith(`--fri-${name}=`))?.split('=').slice(1).join('=');
const subscribe = (channel, callback) => {
  const listener = (_event, value) => callback(value);
  ipcRenderer.on(channel, listener);
  return () => ipcRenderer.removeListener(channel, listener);
};
contextBridge.exposeInMainWorld('friDesktop', {
  platform: process.platform,
  version: argument('version'),
  material: argument('material'),
  windowAction: action => ipcRenderer.invoke('fri:window', action),
  setGlass: enabled => ipcRenderer.invoke('fri:glass', enabled),
  openExternal: url => ipcRenderer.invoke('fri:external', url),
  checkUpdates: () => ipcRenderer.invoke('fri:updates'),
  onCommand: callback => subscribe('fri:command', callback),
  onWindowState: callback => subscribe('fri:window-state', callback)
});
