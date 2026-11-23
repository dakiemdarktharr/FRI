'use strict';
// Desktop pixels stay in the native GPU pipeline. Never expose captures to JS/IPC.
const {screen,nativeTheme,powerMonitor}=require('electron');
let nativeGlass=null;
if(process.platform==='win32'&&(process.env.FRI_TEST_MODE!=='1'||process.env.FRI_TEST_GLASS==='1')){
 try{const candidate=require('@hicccc77/electron-liquid-glass');if(candidate.isSupported())nativeGlass=candidate}catch{}
}
function attachGlass(win,initial=true){
 let panel=null,enabled=initial,destroyed=false,suspended=false,failed=false,watchdog;
 const listeners=[];
 function on(object,event,fn){object.on(event,fn);listeners.push(()=>object.removeListener(event,fn))}
 function bounds(){const b=win.getBounds(),d=screen.getDisplayMatching(b);return {...screen.dipToScreenRect(win,b),dpr:d.scaleFactor}}
 function solid(){win.setBackgroundColor('#151515')}
 function sync(){
  if(destroyed||win.isDestroyed())return;
  const visible=enabled&&!suspended&&!nativeTheme.shouldUseHighContrastColors&&!nativeTheme.prefersReducedTransparency&&win.isVisible()&&!win.isMinimized();
  if(!visible){panel?.hide(0);solid();return}
  if(failed){solid();return}
  try{
   const b=bounds();
   if(!panel){panel=nativeGlass.createPanel({...b,cornerRadius:20,blurSigma:8,displacementScale:45,aberrationIntensity:0,saturation:0,excludeFromCapture:true,anchorWindow:win});if(!panel)throw Error('Glass unavailable');}
   panel.setBounds(b);panel.setParams({dpr:b.dpr,cornerRadius:20,blurSigma:8,displacementScale:45,aberrationIntensity:0,saturation:0});panel.anchor(win);win.setBackgroundColor('#00000000');panel.show(0);
   clearTimeout(watchdog);const before=nativeGlass._native?._stats?.().renders;
   watchdog=setTimeout(()=>{if(!destroyed&&win.isVisible()&&before===0&&nativeGlass._native?._stats?.().renders===0){failed=true;panel.hide(0);solid()}},2500);
  }catch{failed=true;panel?.hide(0);solid()}
 }
 for(const event of ['move','resize','show','hide','minimize','restore','maximize','unmaximize','focus'])on(win,event,sync);
 on(nativeTheme,'updated',sync);on(screen,'display-metrics-changed',sync);on(screen,'display-removed',sync);
 for(const event of ['suspend','lock-screen'])on(powerMonitor,event,()=>{suspended=true;sync()});
 for(const event of ['resume','unlock-screen'])on(powerMonitor,event,()=>{suspended=false;sync()});
 function destroy(){if(destroyed)return;destroyed=true;clearTimeout(watchdog);listeners.forEach(off=>off());panel?.destroy();panel=null}
 on(win,'closed',destroy);
 return {setEnabled(value){if(enabled===value)return;enabled=value;sync()},destroy};
}
module.exports={nativeGlass,attachGlass};
