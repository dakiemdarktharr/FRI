'use strict';
// Windows Explorer owns desktop icon positions. Only the allocated POINT buffer
// is read from Explorer; no file contents or unrelated process memory are read.
let cached;
function widgetPixelBounds(b,display,origin){
 const scale=display.scaleFactor,x=origin.x+Math.round((b.x-display.bounds.x)*scale),y=origin.y+Math.round((b.y-display.bounds.y)*scale);
 const left=Math.floor((x-origin.x)/scale),top=Math.floor((y-origin.y)/scale);
 return {x,y,width:origin.x+Math.floor((left+b.width)*scale)-x,height:origin.y+Math.floor((top+b.height)*scale)-y};
}
function windowsDesktop(){
 if(cached)return cached;
 if(process.platform!=='win32')return null;
 const k=require('koffi'),u=k.load('user32.dll'),kernel=k.load('kernel32.dll');
 const find=u.func('void * __stdcall FindWindowExW(void *, void *, str16, str16)');
 const enumType=k.proto('bool __stdcall FriEnumWindow(void *, intptr_t)');
 const enumerate=u.func('bool __stdcall EnumWindows(FriEnumWindow *, intptr_t)');
 const send=u.func('intptr_t __stdcall SendMessageTimeoutW(void *, uint32_t, uintptr_t, intptr_t, uint32_t, uint32_t, _Out_ uintptr_t *)');
 const getStyle=u.func('intptr_t __stdcall GetWindowLongPtrW(void *, int)');
 const setStyle=u.func('intptr_t __stdcall SetWindowLongPtrW(void *, int, intptr_t)');
 const gdi=k.load('gdi32.dll'),roundRegion=gdi.func('void * __stdcall CreateRoundRectRgn(int,int,int,int,int,int)'),deleteObject=gdi.func('bool __stdcall DeleteObject(void *)'),setRegion=u.func('int __stdcall SetWindowRgn(void *,void *,bool)'),windowRect=u.func('bool __stdcall GetWindowRect(void *,_Out_ void *)');
 const position=u.func('bool __stdcall SetWindowPos(void *,void *,int,int,int,int,uint32_t)');
 const setParent=u.func('void * __stdcall SetParent(void *, void *)');
 const getParent=u.func('void * __stdcall GetParent(void *)'),mapPoints=u.func('int __stdcall MapWindowPoints(void *,void *,_Inout_ void *,uint32_t)');
 const pid=u.func('uint32_t __stdcall GetWindowThreadProcessId(void *, _Out_ uint32_t *)');
 const open=kernel.func('void * __stdcall OpenProcess(uint32_t, bool, uint32_t)');
 const alloc=kernel.func('void * __stdcall VirtualAllocEx(void *, void *, size_t, uint32_t, uint32_t)');
 const read=kernel.func('bool __stdcall ReadProcessMemory(void *, void *, _Out_ void *, size_t, _Out_ size_t *)');
 const free=kernel.func('bool __stdcall VirtualFreeEx(void *, void *, size_t, uint32_t)');
 const close=kernel.func('bool __stdcall CloseHandle(void *)');
 const origin=u.func('bool __stdcall ClientToScreen(void *, _Inout_ void *)');
 function host(){let view=null;enumerate(hwnd=>{const child=find(hwnd,null,'SHELLDLL_DefView',null);if(child){view=child;return false}return true},0);if(!view)throw Error('Windows desktop is unavailable');return {view,list:find(view,null,'SysListView32',null)}}
 function message(hwnd,msg,w=0,l=0){const out=[0];if(!send(hwnd,msg,w,l,2,250,out))throw Error('Explorer did not respond');return Number(out[0])}
 function snapshot(){const {list}=host();if(!list)throw Error('Desktop icons are unavailable');if(Number(getStyle(list,-16))&0x100)throw Error('Turn off Desktop > View > Auto arrange icons to let FRI make space.');const count=message(list,0x1004),processId=[0];pid(list,processId);const process=open(0x38,false,processId[0]);if(!process)throw Error('Explorer access unavailable');const remote=alloc(process,null,8,0x3000,4);if(!remote){close(process);throw Error('Desktop position buffer unavailable')}
  const buffer=Buffer.alloc(8),offset=Buffer.alloc(8);origin(list,offset);const icons=[];
  try{for(let id=0;id<count;id++){if(!message(list,0x1010,id,remote)||!read(process,remote,buffer,8,null))continue;icons.push({id,x:buffer.readInt32LE(0)+offset.readInt32LE(0),y:buffer.readInt32LE(4)+offset.readInt32LE(4)})}}finally{free(process,remote,0,0x8000);close(process)}
  const spacing=message(list,0x1033);return {icons,count,offset:{x:offset.readInt32LE(0),y:offset.readInt32LE(4)},cell:{width:spacing&0xffff,height:(spacing>>>16)&0xffff}};
 }
 function move(id,p){const {list}=host(),offset=Buffer.alloc(8);origin(list,offset);const x=Math.round(p.x-offset.readInt32LE(0)),y=Math.round(p.y-offset.readInt32LE(4));if(x<0||y<0||x>32767||y>32767)return false;return !!message(list,0x100f,id,(x&0xffff)|((y&0xffff)<<16))}
 function round(win){const handle=win.getNativeWindowHandle().readBigUInt64LE(0),screen=require('electron').screen,b=win.getBounds(),scale=screen.getDisplayMatching(b).scaleFactor,p=screen.dipToScreenRect(win,b),rect=Buffer.alloc(16);if(!windowRect(handle,rect))return;const x=p.x-rect.readInt32LE(0),y=p.y-rect.readInt32LE(4),r=Math.round(56*scale),region=roundRegion(x,y,x+p.width+1,y+p.height+1,r,r);if(region&&!setRegion(handle,region,true))deleteObject(region)}
 function bounds(win,b){
  // Electron's Windows DIP rectangle conversion rounds outward on both trips.
  // Feeding getBounds() into setBounds() can therefore grow a frameless widget
  // every time it moves at fractional DPI. Windows rounds the position to the
  // nearest DIP, but encloses the size. Account for both rules when placing the
  // physical pixel edges so getBounds() remains exactly the intended target.
  // The widget uses thickFrame:false, so there are no non-client border insets.
  const screen=require('electron').screen,display=screen.getDisplayMatching(b),origin=screen.dipToScreenPoint({x:display.bounds.x,y:display.bounds.y}),pixels=widgetPixelBounds(b,display,origin);
  const handle=win.getNativeWindowHandle().readBigUInt64LE(0),point=Buffer.alloc(8);point.writeInt32LE(pixels.x,0);point.writeInt32LE(pixels.y,4);
  // Attached desktop widgets are children of Explorer; SetWindowPos then takes
  // parent-client coordinates, while our public bounds remain screen-relative.
  if(Number(getStyle(handle,-16))&0x40000000)mapPoints(null,getParent(handle),point,1);
  // Electron otherwise rejects WM_WINDOWPOSCHANGING sizes for a non-resizable
  // HWND. Restore the preference synchronously before returning to event input.
  const resizable=win.isResizable();if(!resizable)win.setResizable(true);
  try{if(!position(handle,null,point.readInt32LE(0),point.readInt32LE(4),pixels.width,pixels.height,0x14))throw Error('Could not position desktop widget')}finally{if(!resizable)win.setResizable(false)}
  return win.getBounds();
 }
 function attach(win){const {view}=host(),handle=win.getNativeWindowHandle().readBigUInt64LE(0);const style=Number(getStyle(handle,-16));setStyle(handle,-16,(style&~0x80cf0000)|0x40000000);setParent(handle,view);position(handle,null,0,0,0,0,0x37);round(win);return true}
 return cached={snapshot,move,attach,round,bounds};
}
module.exports={windowsDesktop,widgetPixelBounds};
