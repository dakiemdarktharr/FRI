const {test}=require('node:test'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events'),fs=require('node:fs'),path=require('node:path');

test('removing a widget during a pending position save cannot resurrect it',async()=>{
 const handlers=new Map(),windows=[];let state={settings:{desktopWidgets:[]}},release,commits=0;
 class Window extends EventEmitter{
  constructor(bounds){super();this.bounds=bounds;this.webContents={mainFrame:{url:''},setWindowOpenHandler(){},on(){},send(){}};windows.push(this)}
  loadURL(url){this.webContents.mainFrame.url=url}getBounds(){const{x,y,width,height}=this.bounds;return{x,y,width,height}}
  setBounds(b){this.bounds=b}close(){this.emit('closed')}
 }
 const display={bounds:{x:0,y:0,width:1440,height:1000},workArea:{x:0,y:0,width:1440,height:1000}};
 const electron={BrowserWindow:Window,ipcMain:{handle:(key,fn)=>handlers.set(key,fn)},screen:{getDisplayMatching:()=>display,getDisplayNearestPoint:()=>display,getCursorScreenPoint:()=>({x:0,y:0})},Menu:{buildFromTemplate:x=>x},Tray:class{setToolTip(){}setContextMenu(){}on(){}destroy(){}},nativeImage:{createFromPath:()=>({resize(){return{}}})},app:{getPath:()=>path.join(__dirname,'test-results/nonexistent-widget-fixture')}};
 const fakeRequire=name=>name==='electron'?electron:name==='./windows-desktop.cjs'?{windowsDesktop:()=>null}:require(name);
 const module={exports:{}};new Function('require','module','__dirname',fs.readFileSync(path.join(__dirname,'widgets.cjs'),'utf8'))(fakeRequire,module,__dirname);
 const store={read:()=>({state}),commit:async(base,next)=>{commits++;if(commits===1)await new Promise(resolve=>release=resolve);state=next;return{state}}};
 const manager=module.exports.createWidgets({store,getMain:()=>null,onChange(){},onService(){}});
 // Avoid native desktop minimization in this isolated test.
 const prior=process.env.FRI_TEST_MODE;process.env.FRI_TEST_MODE='1';
 try{
  await manager.select();const overlay=windows[0],event={sender:overlay.webContents,senderFrame:overlay.webContents.mainFrame};
  const creating=handlers.get('widget:create')(event,{x:100,y:100,width:360,height:360});
  await new Promise(resolve=>setImmediate(resolve));assert.equal(commits,1);assert.equal(manager.count(),1);
  windows[1].close();assert.equal(manager.count(),0);release();await creating;
  await new Promise(resolve=>setImmediate(resolve));
  assert.deepEqual(state.settings.desktopWidgets,[],'a pending creation save must be followed by the removal save');assert.equal(commits,2);
 }finally{if(prior===undefined)delete process.env.FRI_TEST_MODE;else process.env.FRI_TEST_MODE=prior;manager.cleanup()}
});
