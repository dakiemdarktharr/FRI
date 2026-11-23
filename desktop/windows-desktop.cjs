'use strict';
// Windows Explorer owns desktop icon positions. Only the allocated POINT buffer
// is read from Explorer; no file contents or unrelated process memory are read.
function windowsDesktop(){
 if(process.platform!=='win32')return null;
 const k=require('koffi'),u=k.load('user32.dll'),kernel=k.load('kernel32.dll');
 const find=u.func('void * __stdcall FindWindowExW(void *, void *, str16, str16)');
 const enumType=k.proto('bool __stdcall FriEnumWindow(void *, intptr_t)');
 const enumerate=u.func('bool __stdcall EnumWindows(FriEnumWindow *, intptr_t)');
 const send=u.func('intptr_t __stdcall SendMessageTimeoutW(void *, uint32_t, uintptr_t, intptr_t, uint32_t, uint32_t, _Out_ uintptr_t *)');
 const getStyle=u.func('intptr_t __stdcall GetWindowLongPtrW(void *, int)');
 const setStyle=u.func('intptr_t __stdcall SetWindowLongPtrW(void *, int, intptr_t)');
 const setParent=u.func('void * __stdcall SetParent(void *, void *)');
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
 function attach(win){const {view}=host(),handle=win.getNativeWindowHandle().readBigUInt64LE(0);const style=Number(getStyle(handle,-16));setStyle(handle,-16,(style&~0x80000000)|0x40000000);setParent(handle,view);return true}
 return {snapshot,move,attach};
}
module.exports={windowsDesktop};
