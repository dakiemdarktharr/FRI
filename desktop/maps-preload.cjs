const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('friMap',{read:()=>ipcRenderer.invoke('map:read'),onPlace:fn=>ipcRenderer.on('map:place',(_,value)=>fn(value))});
