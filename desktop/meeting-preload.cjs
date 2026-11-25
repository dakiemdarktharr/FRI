'use strict';
const {contextBridge,ipcRenderer}=require('electron');
const invoke=(action,...args)=>ipcRenderer.invoke('meeting:'+action,...args);
contextBridge.exposeInMainWorld('meeting',{
  sources:()=>invoke('sources'), start:id=>invoke('start',id), stop:token=>invoke('stop',token),
  check:token=>invoke('check',token), state:()=>invoke('state'), login:on=>invoke('login',on),
  frame:(generation,bytes,width)=>invoke('frame',generation,bytes,width),
  onStop:fn=>ipcRenderer.on('meeting:stopped',(_event,message)=>fn(message))
});
