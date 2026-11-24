'use strict';
const {app, BrowserWindow, ipcMain, Menu, dialog, shell, protocol, nativeTheme, session, screen, safeStorage, Notification} = require('electron');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const {createStore}=require('./store.cjs');
const {createWidgets}=require('./widgets.cjs');
const {createServices}=require('./services.cjs');
const {nativeGlass, attachGlass}=require('./glass.cjs');
const {autoUpdater} = require('electron-updater');

// A stable origin and userData directory keep calendar storage across installations.
app.setName('FRI');
app.setAppUserModelId('com.fri.calendar');
const testData = process.env.FRI_TEST_USER_DATA;
if (testData && process.env.FRI_TEST_MODE === '1') app.setPath('userData', path.resolve(testData));
protocol.registerSchemesAsPrivileged([{scheme:'app', privileges:{standard:true, secure:true, supportFetchAPI:true}}]);
const startURL = 'app://fri/index.html';
const uiPath = path.join(__dirname, 'ui');
const isMac = process.platform === 'darwin';
const supportsAcrylic = process.platform === 'win32' && Number(os.release().split('.')[2]) >= 22621;
const material = nativeGlass ? 'liquid-glass' : isMac ? 'vibrancy' : supportsAcrylic ? 'acrylic' : 'solid';
let store, widgets, services, quitting=false;
let glassController;
let win, updates;

function trusted(event) {
  if (!win || event.sender !== win.webContents || event.senderFrame !== win.webContents.mainFrame || event.senderFrame.url !== startURL) throw new Error('Untrusted IPC sender');
}
const permittedLinks = new Set(['https://calendar.google.com/', 'https://open.spotify.com/', 'https://github.com/dakiemdarktharr/FRI', 'https://github.com/dakiemdarktharr/FRI/releases/latest']);
function openExternal(url) {
  if (typeof url !== 'string' || !permittedLinks.has(new URL(url).href)) throw new Error('External destination is not allowed');
  return shell.openExternal(url);
}
function emitState() { if(win&&!win.isDestroyed())win.webContents.send('fri:window-state',{maximized:win.isMaximized(),focused:win.isFocused()}); }
function windowAction(action) {
  if(!win||win.isDestroyed())return;
  switch(action){
    case 'minimize':win.minimize();break;
    case 'maximize':win.isMaximized()?win.unmaximize():win.maximize();break;
    case 'fullscreen':win.setFullScreen(!win.isFullScreen());break;
    case 'close':win.close();break;
    default:throw new Error('Unknown window action');
  }
}
function setGlass(enabled) {
  if(typeof enabled!=='boolean')throw new Error('Invalid material preference');
  if(glassController){glassController.setEnabled(enabled);return;}
  if(supportsAcrylic)win.setBackgroundMaterial(enabled?'acrylic':'none');
  if(isMac)win.setVibrancy(enabled?'under-window':null);
  win.setBackgroundColor(enabled&&material!=='solid'?'#00000000':'#151515');
}
function send(command){if(command==='desktop-widget'){widgets?.select();return}win?.webContents.send('fri:command',command);}
function changed(){const payload=store.read();win?.webContents.send('fri:state',payload);widgets?.broadcast();}
function nativeMenu(){
  const item=(label,command,accelerator)=>({label,accelerator,click:()=>send(command)});
  const template=[
    ...(isMac?[{label:'FRI',submenu:[item('About FRI','about'),{type:'separator'},item('Settings…','settings','Cmd+,'),{type:'separator'},{role:'hide'},{role:'hideOthers'},{role:'unhide'},{type:'separator'},{role:'quit'}]}]:[]),
    {label:'File',submenu:[item('Add a source','intake'),item('Refresh prepared sources','refresh'),item('Find time for a task','focus'),item('Find time together','together'),{type:'separator'},item('Create FRI widget on desktop','desktop-widget'),{type:'separator'},item('New deadline','deadline'),item('New schedule','schedule','CommandOrControl+N'),{type:'separator'},item('Export calendar backup…','export'),item('Restore calendar backup…','import'),{type:'separator'},{role:'close'}]},
    {label:'Edit',submenu:[{role:'undo'},{role:'redo'},{type:'separator'},{role:'cut'},{role:'copy'},{role:'paste'},{role:'selectAll'},{type:'separator'},item('Search appointments','search','CommandOrControl+F'),item('Edit appointments','manage')]},
    {label:'View',submenu:[item('Toggle sidebar','sidebar','CommandOrControl+B'),item('My feed','day'),item('Week','week'),item('Month','month'),item('Year','year'),{type:'separator'},{role:'togglefullscreen'}]},
    {label:'Help',submenu:[item('Keyboard shortcuts','shortcuts'),{label:'Check for updates…',click:()=>send('updates')},item('About FRI','about')]}
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}
function createWindow(){
  const workArea=screen.getPrimaryDisplay().workAreaSize;
  win=new BrowserWindow({
    width:Math.min(1440,Math.max(860,workArea.width-80)),height:Math.min(980,Math.max(640,workArea.height-80)),minWidth:640,minHeight:480,show:false,frame:false,roundedCorners:true,
    title:'FRI',autoHideMenuBar:true,backgroundColor:material==='solid'?'#151515':'#00000000',
    ...(nativeGlass?{transparent:true}:supportsAcrylic?{backgroundMaterial:'acrylic'}:{}),
    ...(isMac?{vibrancy:'under-window',visualEffectState:'active'}:{}),
    webPreferences:{preload:path.join(__dirname,'preload.cjs'),nodeIntegration:false,contextIsolation:true,sandbox:true,webSecurity:true,allowRunningInsecureContent:false,
      additionalArguments:[`--fri-version=${app.getVersion()}`,`--fri-material=${material}`]}
  });
  if(nativeGlass)glassController=attachGlass(win,store.read().state?.settings?.glass!==false);
  win.setMenuBarVisibility(false);
  win.webContents.setWindowOpenHandler(({url})=>{try{openExternal(url)}catch{}return {action:'deny'};});
  win.webContents.on('will-navigate',(event,url)=>{if(url!==startURL)event.preventDefault();});
  win.webContents.on('will-attach-webview',event=>event.preventDefault());
  for(const event of ['maximize','unmaximize','focus','blur'])win.on(event,emitState);
  win.once('ready-to-show',()=>{if(!(process.env.FRI_TEST_MODE==='1'&&process.env.FRI_TEST_HIDDEN==='1'))win.show();emitState()});
  win.on('close',e=>{if(!quitting&&widgets?.count()){e.preventDefault();win.hide()}});
  win.on('closed',()=>{win=null});
  win.loadURL(startURL);
}

if(!app.requestSingleInstanceLock()){app.quit();}else{
  app.on('second-instance',()=>{if(win){if(win.isMinimized())win.restore();win.show();win.focus()}});
  app.whenReady().then(async()=>{
    nativeTheme.themeSource='dark';
    store=createStore(app.getPath('userData'),safeStorage);
    try{await store.init()}catch(e){dialog.showErrorBox('FRI — Secure storage',e.message);app.quit();return}
    const csp=JSON.parse(fs.readFileSync(path.join(uiPath,'csp.json'),'utf8'));
    protocol.handle('app',request=>{
      const widgetFiles={'app://fri/widget.html':'widget.html','app://fri/widget-select.html':'widget-select.html'};
      if(widgetFiles[request.url]){const html=fs.readFileSync(path.join(__dirname,widgetFiles[request.url]),'utf8').replace(/\r\n?/g,'\n').replace('<link rel="stylesheet" href="widget.css">',()=>'<style>'+fs.readFileSync(path.join(__dirname,'widget.css'),'utf8')+'</style>');const hash=require('node:crypto').createHash('sha256').update(html.match(/<script>([\s\S]*?)<\/script>/)[1]).digest('base64');return new Response(html,{headers:{'content-type':'text/html; charset=utf-8','Content-Security-Policy':"default-src 'none'; script-src 'sha256-"+hash+"'; style-src 'unsafe-inline'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"}})}
      if(request.url!==startURL)return new Response('Not found',{status:404});
      return new Response(fs.readFileSync(path.join(uiPath,'index.html')),{headers:{'content-type':'text/html; charset=utf-8','Content-Security-Policy':csp,'X-Content-Type-Options':'nosniff'}});
    });
    // No renderer networking is needed for local calendar functionality.
    session.defaultSession.webRequest.onBeforeRequest({urls:['http://*/*','https://*/*']},(_details,callback)=>callback({cancel:true}));
    session.defaultSession.setPermissionRequestHandler((_contents,_permission,callback)=>callback(false));
    session.defaultSession.setPermissionCheckHandler(()=>false);
    ipcMain.handle('fri:window',(e,action)=>{trusted(e);windowAction(action)});
    ipcMain.handle('fri:glass',(e,enabled)=>{trusted(e);setGlass(enabled)});
    ipcMain.handle('fri:external',(e,url)=>{trusted(e);return openExternal(url)});
    updates=require('./updates.cjs').createUpdates({updater:autoUpdater,version:app.getVersion(),platform:process.platform,packaged:app.isPackaged,testMode:process.env.FRI_TEST_MODE==='1',
      publish:state=>{if(win&&!win.isDestroyed())win.webContents.send('fri:update-state',state)},
      openReleases:()=>openExternal('https://github.com/dakiemdarktharr/FRI/releases/latest'),
      confirmInstall:async()=>{const choice=await dialog.showMessageBox(win,{type:'question',message:'Restart Fri to install the update?',detail:'Your calendar and settings stay on this device.',buttons:['Restart and install','Later'],defaultId:1,cancelId:1});return choice.response===0},
      prepareInstall:async()=>{if(!win||win.isDestroyed())throw Error('Calendar window is unavailable');await win.webContents.executeJavaScript('if (typeof window.FRI_PREVIEW?.flush !== "function") throw Error("Calendar is not ready"); window.FRI_PREVIEW.flush();');await store.settled()}
    });
    ipcMain.handle('fri:updates',(e,action='check')=>{trusted(e);return updates.call(action)});
    services=createServices({store,changed});
    ipcMain.handle('fri:load-state',e=>{trusted(e);return store.read()});
    ipcMain.handle('fri:save-state',async(e,base,next)=>{trusted(e);const result=await store.commit(base,next);changed();return result});
    ipcMain.handle('fri:widget',e=>{trusted(e);return widgets.select()});
    ipcMain.handle('fri:service',async(e,action,input)=>{trusted(e);return services.call(action,input)});
    widgets=createWidgets({store,getMain:()=>win,onChange:changed,onService:action=>{const settings=store.read().state.settings;return services.call(action,action==='spotify'?settings.spotifyUrl:settings.mapsRegion)}});
    nativeMenu();createWindow();widgets.restore();updates.start();
    app.on('activate',()=>{if(!win)createWindow()});
  });
  app.on('window-all-closed',()=>{if(!isMac)app.quit()});
  app.on('before-quit',e=>{if(quitting)return;e.preventDefault();quitting=true;widgets?.cleanup();services?.stop();updates?.stop();glassController?.destroy();nativeGlass?.shutdown();Promise.resolve(store?.settled()).finally(()=>app.quit())});
}
