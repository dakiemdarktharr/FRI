'use strict';
// Inspect only the foreground HWND. Never enumerate titles or read other apps.
let foreground;
function isForeground(sourceId){
 if(process.platform!=='win32')return true;
 try{
  if(!foreground)foreground=require('koffi').load('user32.dll').func('uintptr_t __stdcall GetForegroundWindow()');
  const handle=String(sourceId).match(/^window:(\d+):/);return !!handle&&BigInt(foreground())===BigInt(handle[1]);
 }catch{return false;}
}
module.exports={isForeground};
