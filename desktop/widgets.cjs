'use strict';
const {BrowserWindow,ipcMain,screen,Menu,Tray,nativeImage}=require('electron');
const path=require('node:path'),{execFile}=require('node:child_process'),{relocateIcons}=require('./widget-layout.cjs');
const {windowsDesktop}=require('./windows-desktop.cjs');
function createWidgets({store,getMain,onChange,onService}){
 const windows=new Map();let shuttingDown=false,overlay=null,selectionDisplay=null,tray=null,native=null,notice='',moveTimer,boundsQueue=Promise.resolve();
 const fs=require('node:fs'),journal=path.join(require('electron').app.getPath('userData'),'desktop-icon-positions.json');
 const shifted=new Map();let iconCount=null;
 try{native=windowsDesktop()}catch{notice='Desktop icon placement is unavailable on this system.'}
 try{if(native&&fs.existsSync(journal)){const saved=JSON.parse(fs.readFileSync(journal,'utf8')),actual=native.snapshot();if(saved.count===actual.count&&JSON.stringify(saved.positions)===JSON.stringify(actual.icons))for(const m of saved.moves)native.move(m.id,m.from);fs.unlinkSync(journal)}}catch{}
 function read(){return {...store.read(),notice}}
 function broadcast(){for(const w of windows.values())if(!w.isDestroyed())w.webContents.send('widget:state',read())}
 function trusted(e,selection=false){const w=selection?overlay:[...windows.values()].find(w=>w.webContents===e.sender);const url=selection?'app://fri/widget-select.html':'app://fri/widget.html';if(!w||e.sender!==w.webContents||e.senderFrame!==w.webContents.mainFrame||e.senderFrame.url!==url)throw Error('Untrusted widget request');return w}
 function secure(w,url){w.webContents.setWindowOpenHandler(()=>({action:'deny'}));w.webContents.on('will-navigate',(e,to)=>{if(to!==url)e.preventDefault()});w.loadURL(url)}
 function saveBounds(){const operation=boundsQueue.then(async()=>{const base=store.read().state;if(!base)return;const next=structuredClone(base);next.settings.desktopWidgets=[...windows.entries()].map(([id,w])=>({id,...w.getBounds()}));if(JSON.stringify(base.settings.desktopWidgets)===JSON.stringify(next.settings.desktopWidgets))return;await store.commit(base,next);onChange()});boundsQueue=operation.catch(()=>{});return operation}
 function reconcileIcons(){
  if(!native||(process.env.FRI_TEST_MODE==='1'&&process.env.FRI_TEST_NATIVE_DESKTOP!=='1'))return;
  try{const snap=native.snapshot();if(iconCount!==null&&snap.count!==iconCount)shifted.clear();iconCount=snap.count;
   const rects=[...windows.values()].map(w=>screen.dipToScreenRect(null,w.getBounds()));
   const area=screen.getAllDisplays().map(display=>screen.dipToScreenRect(null,display.workArea)),cell={width:snap.cell.width||86,height:snap.cell.height||96};
   for(const move of relocateIcons(snap.icons,rects,area,cell)){if(native.move(move.id,move.to)){const old=shifted.get(move.id);shifted.set(move.id,{from:old?.from||move.from,to:move.to})}}
   const applied=native.snapshot();for(const [id,entry] of shifted){const actual=applied.icons.find(i=>i.id===id);if(actual)entry.to={x:actual.x,y:actual.y}}
   if(shifted.size)fs.writeFileSync(journal,JSON.stringify({count:applied.count,positions:applied.icons,moves:[...shifted].map(([id,m])=>({id,...m}))}),{mode:0o600});
   notice='';broadcast();
  }catch(e){notice=e.message;broadcast()}
 }
 function restoreIcons(){if(!native||!shifted.size)return;try{const snap=native.snapshot();if(snap.count===iconCount)for(const [id,p] of shifted){const actual=snap.icons.find(i=>i.id===id);if(actual&&Math.abs(actual.x-p.to.x)<2&&Math.abs(actual.y-p.to.y)<2)native.move(id,p.from)}}catch{}shifted.clear();try{fs.unlinkSync(journal)}catch{}}
 function ensureTray(){if(tray)return;tray=new Tray(nativeImage.createFromPath(path.join(__dirname,'resources/icon.png')).resize({width:20,height:20}));tray.setToolTip('FRI');tray.setContextMenu(Menu.buildFromTemplate([{label:'Open FRI',click:()=>{getMain()?.show();getMain()?.focus()}},{label:'Create desktop widget',click:()=>select()},{label:'Quit FRI',click:()=>require('electron').app.quit()}]));tray.on('double-click',()=>getMain()?.show())}
 function setBounds(w,target){
  const actual=w.getBounds();if(['x','y','width','height'].every(k=>actual[k]===target[k]))return actual;
  if(native?.bounds)try{return native.bounds(w,target)}catch{notice='Precise desktop positioning is unavailable. Using standard window positioning.'}
  w.setBounds(target);return w.getBounds();
 }
 function make(bounds,id=require('node:crypto').randomUUID()){
  const display=screen.getDisplayMatching(bounds),area=display.workArea;
  const width=Math.min(area.width,Math.max(220,Math.round(bounds.width))),height=Math.min(area.height,Math.max(150,Math.round(bounds.height)));
  const w=new BrowserWindow({x:Math.max(area.x,Math.min(bounds.x,area.x+area.width-width)),y:Math.max(area.y,Math.min(bounds.y,area.y+area.height-height)),width,height,minWidth:220,minHeight:150,maxWidth:1000,maxHeight:1000,frame:false,thickFrame:false,transparent:process.platform!=='win32',backgroundColor:process.platform==='win32'?'#eaf0f4':'#00000000',hasShadow:false,roundedCorners:true,resizable:process.platform!=='win32',skipTaskbar:true,show:false,webPreferences:{preload:path.join(__dirname,'widget-preload.cjs'),sandbox:true,contextIsolation:true,nodeIntegration:false,webSecurity:true}});
  setBounds(w,{x:Math.max(area.x,Math.min(Math.round(bounds.x),area.x+area.width-width)),y:Math.max(area.y,Math.min(Math.round(bounds.y),area.y+area.height-height)),width,height});
  windows.set(id,w);secure(w,'app://fri/widget.html');w.once('ready-to-show',()=>{if(!(process.env.FRI_TEST_MODE==='1'&&process.env.FRI_TEST_HIDDEN==='1'))w.show();if(native&&(process.env.FRI_TEST_MODE!=='1'||process.env.FRI_TEST_NATIVE_DESKTOP==='1'))try{native.attach(w)}catch{notice='Widget is in a normal window; desktop attachment is unavailable.'}reconcileIcons()});
  const moved=()=>{clearTimeout(moveTimer);moveTimer=setTimeout(()=>{saveBounds().catch(()=>{notice='Could not save the widget position. Try moving it again.';broadcast()});reconcileIcons()},250)};w.on('move',moved);w.on('resize',()=>{setTimeout(()=>{if(!w.isDestroyed())try{native?.round(w)}catch{}},40);moved()});w.on('closed',()=>{windows.delete(id);if(shuttingDown)return;if(!windows.size)restoreIcons();else reconcileIcons();saveBounds().catch(()=>{notice='Could not save the widget position. Try moving it again.';broadcast()})});ensureTray();return w;
 }
 async function select(){if(overlay)return;selectionDisplay=screen.getDisplayNearestPoint(screen.getCursorScreenPoint());getMain()?.hide();
  if(process.platform==='win32'&&process.env.FRI_TEST_MODE!=='1')await new Promise(resolve=>execFile('powershell.exe',['-NoProfile','-NonInteractive','-Command','(New-Object -ComObject Shell.Application).MinimizeAll()'],{windowsHide:true,timeout:4000},()=>resolve()));
  overlay=new BrowserWindow({...selectionDisplay.bounds,frame:false,transparent:true,alwaysOnTop:true,skipTaskbar:true,resizable:false,show:false,webPreferences:{preload:path.join(__dirname,'widget-preload.cjs'),sandbox:true,contextIsolation:true,nodeIntegration:false}});secure(overlay,'app://fri/widget-select.html');overlay.once('ready-to-show',()=>{if(!(process.env.FRI_TEST_MODE==='1'&&process.env.FRI_TEST_HIDDEN==='1')){overlay.show();overlay.focus()}});overlay.on('closed',()=>overlay=null)
 }
 ipcMain.handle('widget:bounds',(e,b)=>{const w=trusted(e);if(b===undefined)return w.getBounds();if(!b||!['x','y','width','height'].every(k=>Number.isFinite(b[k])&&Math.abs(b[k])<100000))throw Error('Invalid widget bounds');const area=screen.getDisplayMatching(b).workArea,width=Math.round(Math.min(area.width,1000,Math.max(220,b.width))),height=Math.round(Math.min(area.height,1000,Math.max(150,b.height)));setBounds(w,{x:Math.round(Math.max(area.x,Math.min(b.x,area.x+area.width-width))),y:Math.round(Math.max(area.y,Math.min(b.y,area.y+area.height-height))),width,height});try{native?.round(w)}catch{}return w.getBounds()});
 ipcMain.handle('widget:read',e=>{trusted(e);return read()});
 ipcMain.handle('widget:done',async(e,id)=>{trusted(e);const base=store.read().state,next=structuredClone(base),task=next?.tasks.find(t=>t.id===id);if(!task)throw Error('Appointment no longer exists');task.done=true;await store.commit(base,next);onChange();broadcast();return read()});
 ipcMain.handle('widget:create',async(e,b)=>{trusted(e,true);if(!b||!['x','y','width','height'].every(k=>Number.isFinite(b[k])))throw Error('Invalid widget area');const area=selectionDisplay.bounds;overlay.close();const w=make({x:area.x+b.x,y:area.y+b.y,width:b.width,height:b.height});await saveBounds();return {created:true}});
 ipcMain.handle('widget:cancel',e=>{trusted(e,true);overlay.close();getMain()?.show()});
 ipcMain.handle('widget:action',(e,action)=>{const w=trusted(e);if(action==='remove')w.close();else if(action==='open'){getMain()?.show();getMain()?.focus()}else if(action==='add'||action==='integrations'){const main=getMain();main?.show();main?.focus();main?.webContents.send('fri:command',action==='add'?'schedule':'widgets')}else if(action==='spotify'||action==='maps')return onService(action);else throw Error('Unknown widget action')});
 return {select,broadcast,restore(){for(const b of store.read().state?.settings?.desktopWidgets||[])if(b&&['x','y','width','height'].every(k=>Number.isFinite(b[k])))make(b,b.id)},cleanup(){shuttingDown=true;clearTimeout(moveTimer);restoreIcons();tray?.destroy()},count:()=>windows.size};
}
module.exports={createWidgets};
