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
  loadState:()=>ipcRenderer.invoke('fri:load-state'),
  saveState:(base,next)=>ipcRenderer.invoke('fri:save-state',base,next),
  createWidget:()=>ipcRenderer.invoke('fri:widget'),
  service:(action,input)=>ipcRenderer.invoke('fri:service',action,input),
  onState:callback=>subscribe('fri:state',callback),
  checkUpdates: () => ipcRenderer.invoke('fri:updates'),
  onCommand: callback => subscribe('fri:command', callback),
  onWindowState: callback => subscribe('fri:window-state', callback)
});
