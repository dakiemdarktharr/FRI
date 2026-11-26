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
  openUsageGuide:()=>ipcRenderer.invoke('fri:guide-open'),
  finishUsageGuide:()=>ipcRenderer.invoke('fri:guide-finish'),
  openMeetingAgent:()=>ipcRenderer.invoke('fri:meeting-open'),
  onMeetingReview:callback=>subscribe('fri:meeting-review',callback),
  createWidget:()=>ipcRenderer.invoke('fri:widget'),
  service:(action,input)=>ipcRenderer.invoke('fri:service',action,input),
  onState:callback=>subscribe('fri:state',callback),
  checkUpdates: () => ipcRenderer.invoke('fri:updates','check'),
  updateAction: action => ipcRenderer.invoke('fri:updates',action),
  onUpdateState: callback => subscribe('fri:update-state', callback),
  onCommand: callback => subscribe('fri:command', callback),
  onWindowState: callback => subscribe('fri:window-state', callback)
});
