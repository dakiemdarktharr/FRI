const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('friWidget',{
 bounds:value=>ipcRenderer.invoke('widget:bounds',value),
 platform:process.platform,
 read:()=>ipcRenderer.invoke('widget:read'),done:id=>ipcRenderer.invoke('widget:done',id),
 create:bounds=>ipcRenderer.invoke('widget:create',bounds),cancel:()=>ipcRenderer.invoke('widget:cancel'),
 action:action=>ipcRenderer.invoke('widget:action',action),
 onState:fn=>{const handler=(_,v)=>fn(v);ipcRenderer.on('widget:state',handler);return()=>ipcRenderer.removeListener('widget:state',handler)}
});
