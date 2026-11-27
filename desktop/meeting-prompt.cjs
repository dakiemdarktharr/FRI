'use strict';
const {BrowserWindow,ipcMain,screen}=require('electron');
const path=require('node:path');
const url=require('node:url').pathToFileURL(path.join(__dirname,'meeting-prompt.html')).href;
function createMeetingPrompt(){
 let current;
 function close(){current?.close();}
 function show(item,theme){return new Promise(resolve=>{
  close();const area=screen.getPrimaryDisplay().workArea;
  const win=new BrowserWindow({width:360,height:228,x:area.x+area.width-380,y:area.y+area.height-248,show:false,frame:false,resizable:false,alwaysOnTop:true,skipTaskbar:true,backgroundColor:theme==='dark'?'#1c2d3b':'#ffffff',webPreferences:{preload:path.join(__dirname,'meeting-prompt-preload.cjs'),sandbox:true,contextIsolation:true,nodeIntegration:false}});
  current=win;let answer=1;
  const reply=(event,value)=>{if(event.sender!==win.webContents||event.senderFrame!==win.webContents.mainFrame||event.senderFrame.url!==url||![0,1].includes(value))return;answer=value;win.close();};
  ipcMain.on('meeting:prompt-answer',reply);
  win.webContents.setWindowOpenHandler(()=>({action:'deny'}));win.webContents.on('will-navigate',event=>event.preventDefault());
  win.once('closed',()=>{ipcMain.removeListener('meeting:prompt-answer',reply);if(current===win)current=null;resolve({response:answer});});
  win.loadURL(url).then(()=>{if(win.isDestroyed())return;win.webContents.send('meeting:prompt-data',{item,theme});if(!(process.env.FRI_TEST_MODE==='1'&&process.env.FRI_TEST_HIDDEN==='1'))win.showInactive();}).catch(()=>win.close());
 });}
 return {show,close};
}
module.exports={createMeetingPrompt};
