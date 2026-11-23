'use strict';
const {BrowserWindow,session,ipcMain,shell,app}=require('electron');
const path=require('node:path');
function createMap(){
 let window=null,place=null;const partition='persist:fri-maps-opt-in',isolated=session.fromPartition(partition);
 isolated.setUserAgent(`FRI/${app.getVersion()} (+https://github.com/dakiemdarktharr/FRI)`);
 isolated.webRequest.onBeforeRequest({urls:['http://*/*','https://*/*']},(d,cb)=>{const u=new URL(d.url);cb({cancel:!(u.protocol==='https:'&&u.hostname==='tile.openstreetmap.org'&&/^\/\d+\/\d+\/\d+\.png$/.test(u.pathname))})});
 isolated.setPermissionRequestHandler((_w,_p,cb)=>cb(false));isolated.setPermissionCheckHandler(()=>false);
 ipcMain.handle('map:read',e=>{if(!window||e.sender!==window.webContents||e.senderFrame!==window.webContents.mainFrame)throw Error('Untrusted map request');return place});
 return {open(value){place=value;if(window&&!window.isDestroyed()){window.webContents.send('map:place',place);window.show();window.focus();return}
  window=new BrowserWindow({title:'Maps · FRI',width:860,height:620,minWidth:360,minHeight:320,autoHideMenuBar:true,backgroundColor:'#191919',webPreferences:{partition,preload:path.join(__dirname,'maps-preload.cjs'),nodeIntegration:false,contextIsolation:true,sandbox:true,webSecurity:true}});
  window.webContents.setWindowOpenHandler(({url})=>{try{const u=new URL(url);if(u.protocol==='https:'&&u.hostname==='www.openstreetmap.org')shell.openExternal(u.href)}catch{}return {action:'deny'}});
  window.webContents.on('will-navigate',e=>e.preventDefault());window.on('closed',()=>window=null);window.loadFile(path.join(__dirname,'maps.html'));
 },async disconnect(){window?.close();place=null;await isolated.clearCache();await isolated.clearStorageData()},close(){window?.close()}};
}
module.exports={createMap};
