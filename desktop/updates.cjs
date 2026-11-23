'use strict';

// The renderer receives state, never installer paths or arbitrary download URLs.
function newer(candidate,current){
 const parse=v=>typeof v==='string'&&/^\d+\.\d+\.\d+$/.test(v)?v.split('.').map(Number):null;
 const a=parse(candidate),b=parse(current);if(!a||!b||a.some(n=>!Number.isSafeInteger(n)))return false;
 for(let i=0;i<3;i++){if(a[i]!==b[i])return a[i]>b[i]}return false;
}
function createUpdates({updater,version,platform,packaged,testMode=false,publish=()=>{},prepareInstall=async()=>{},confirmInstall=async()=>true,openReleases=async()=>{}}){
 const enabled=packaged&&!testMode,automatic=platform==='win32';
 let state={phase:enabled?'idle':'unavailable',currentVersion:version,latestVersion:null,percent:0,message:enabled?'':'Updates are available in installed release builds.',automatic};
 let operation=null,stopped=false,startTimer=null,interval=null;
 const read=()=>({...state});
 const set=patch=>{state={...state,...patch};publish(read());return read()};
 const error=()=>set({phase:'error',percent:0,message:'The update could not finish. Check your connection and try again.'});
 const handlers={
  'update-available':info=>{if(state.phase!=='checking')return;if(!newer(info?.version,version)){error();return}set({phase:automatic?'available':'manual',latestVersion:info.version,percent:0,message:automatic?'Download when you are ready. Your calendar stays on this device.':'This build uses a manual installer on your platform. Open the official release to update.'})},
  'update-not-available':()=>{if(state.phase==='checking')set({phase:'current',latestVersion:null,message:'You are using the latest release.'})},
  'download-progress':progress=>{if(state.phase==='downloading'&&Number.isFinite(progress?.percent))set({percent:Math.max(0,Math.min(100,Math.floor(progress.percent)))})},
  'update-downloaded':info=>{if(state.phase!=='downloading')return;if(info?.version!==state.latestVersion){error();return}set({phase:'ready',percent:100,message:'The update is verified and ready. Restart when you are ready.'})},
  'error':()=>{if(!stopped&&['checking','downloading','installing'].includes(state.phase))error()}
 };
 updater.autoDownload=false;updater.autoInstallOnAppQuit=false;updater.allowDowngrade=false;updater.allowPrerelease=false;
 for(const [name,fn] of Object.entries(handlers))updater.on(name,fn);
 function run(fn){if(operation)return operation;operation=Promise.resolve().then(fn).catch(()=>error()).finally(()=>{operation=null});return operation}
 function check(){
  if(!enabled||stopped)return Promise.resolve(read());
  if(operation||['downloading','ready','installing'].includes(state.phase))return operation||Promise.resolve(read());
  return run(async()=>{set({phase:'checking',message:'Checking the official release feed…'});await updater.checkForUpdates();if(state.phase==='checking')error();return read()});
 }
 async function download(){
  if(operation)return operation;
  if(stopped||!enabled||!automatic||state.phase!=='available')throw Error('No downloadable update is available.');
  return run(async()=>{set({phase:'downloading',percent:0,message:'Downloading the update. You can keep using Fri.'});await updater.downloadUpdate();if(state.phase==='downloading')error();return read()});
 }
 async function install(){
  if(operation)return operation;
  if(stopped||!enabled||!automatic||state.phase!=='ready')throw Error('A verified update must be downloaded first.');
  return run(async()=>{
   set({phase:'installing',message:'Preparing to restart Fri…'});
   if(!await confirmInstall()){set({phase:'ready',message:'The update is ready whenever you are.'});return read()}
   try{await prepareInstall()}catch{set({phase:'ready',message:'Your latest changes are not saved yet. Keep Fri open and retry.'});return read()}
   updater.quitAndInstall(false,true);return read();
  });
 }
 return {read,check,download,install,
  async call(action){
   if(action==='status')return read();if(action==='check')return check();if(action==='download')return download();if(action==='install')return install();
   if(action==='open-releases'){if(stopped||!enabled||state.phase!=='manual')throw Error('No manual update is available.');await openReleases();return read()}
   throw Error('Unknown update action');
  },
  start(){if(!enabled||startTimer||interval||stopped)return;startTimer=setTimeout(()=>{startTimer=null;void check()},4000);startTimer.unref?.();interval=setInterval(()=>void check(),30*60*1000);interval.unref?.()},
  stop(){stopped=true;clearTimeout(startTimer);clearInterval(interval);for(const [name,fn] of Object.entries(handlers))if(name!=='error')updater.removeListener(name,fn)}
 };
}
module.exports={createUpdates,newer};
