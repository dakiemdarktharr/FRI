'use strict';
const {BrowserWindow,Menu,session,dialog,safeStorage}=require('electron'),fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {validateSourceUrl,readPublicDetails}=require('./public-source.cjs');
const partitionFor=origin=>'persist:fri-source-'+crypto.createHash('sha256').update(origin).digest('hex').slice(0,24);
function relatedLinks(page){
 const origin=new URL(page.url).origin;
 return (page.links||[]).filter(link=>{try{const u=new URL(link.url);if(u.origin!==origin||u.username||u.password)return false;
  // Only observed, read-only Moodle views. Never follow submission, enrolment or session-token links.
  if(!/^\/(calendar\/view|course\/view|mod\/assign\/view)\.php$/.test(u.pathname))return false;
  if([...u.searchParams.keys()].some(k=>!['id','view','time','course','courseid','lang'].includes(k)))return false;
  const dates=link.title.match(/\d{2}\/\d{2}\/\d{4}/g);if(u.pathname==='/course/view.php'&&dates?.length>=2){const [d,m,y]=dates.at(-1).split('/');if(new Date(+y,+m-1,+d,23,59)<new Date())return false}
  return true;
 }catch{return false}}).sort((a,b)=>Number(/mod\/assign|calendar/.test(b.url))-Number(/mod\/assign|calendar/.test(a.url)));
}
const READ_PAGE=`(()=>{const visible=e=>!!(e.offsetWidth||e.offsetHeight||e.getClientRects().length);const login=[...document.querySelectorAll('input[type=password]')].some(visible)||/\\/(login|signin|auth)(\\/|\\.|$)/i.test(location.pathname);if(login)return {state:'sign-in',text:'',url:location.href};const clone=(document.querySelector('[role=main],#region-main,main')||document.body).cloneNode(true);clone.querySelectorAll('script,style,noscript,input,textarea,select,[hidden],[aria-hidden=true],.d-none,nav,header,footer').forEach(e=>e.remove());const text=clone.innerText||clone.textContent||'';const structured=[...document.querySelectorAll('script[type="application/ld+json"]')].map(e=>e.textContent).join('\\n');return {state:'ready',text:text.replace(/[ \\t]+/g,' ').slice(0,60000),structured:structured.slice(0,60000),url:location.href,title:document.title,links:[...document.querySelectorAll('a[href]')].map(a=>({title:(a.innerText||'').trim().slice(0,120),url:a.href})).filter(a=>a.title&&/^https:/.test(a.url)&&(/calendar|assign|course|lịch|bài tập|timeline/i.test(a.title+' '+a.url))).filter(a=>{const u=new URL(a.url);return u.origin===location.origin&&!u.searchParams.has('sesskey')&&!/logout|delete|enrol|unenrol/.test(u.pathname)}).filter((a,i,all)=>all.findIndex(b=>b.url===a.url)===i).sort((a,b)=>Number(/calendar|assign/.test(b.url))-Number(/calendar|assign/.test(a.url))).slice(0,80)}})()`;
function createSourceBrowser({directory}){
 const file=path.join(directory,'source-sessions.json'),windows=new Set(),guarded=new Set();
 const atomic=async(file,bytes)=>{const temporary=file+'.'+crypto.randomUUID()+'.pending';await fs.writeFile(temporary,bytes,{mode:0o600});try{await fs.rename(temporary,file)}finally{await fs.unlink(temporary).catch(()=>{})}};
 const cookieFile=origin=>path.join(directory,partitionFor(origin).replace('persist:','')+'.cookies.encrypted');
 async function persistCookies(origin,s){if(!await safeStorage.isAsyncEncryptionAvailable())throw Error('Unlock the system keychain to remember this sign-in.');const bytes=await safeStorage.encryptStringAsync(JSON.stringify(await s.cookies.get({})));await atomic(cookieFile(origin),bytes);await s.cookies.flushStore()}
 async function restoreCookies(origin,s){try{const decoded=await safeStorage.decryptStringAsync(await fs.readFile(cookieFile(origin)));for(const c of JSON.parse(decoded.result)){if(c.expirationDate&&c.expirationDate<Date.now()/1000)continue;const hostname=c.domain.replace(/^\./,'');const item={url:(c.secure?'https:':'http:')+'//'+hostname+(c.path||'/'),name:c.name,value:c.value,path:c.path,secure:c.secure,httpOnly:c.httpOnly,sameSite:c.sameSite};if(!c.hostOnly)item.domain=c.domain;if(c.expirationDate)item.expirationDate=c.expirationDate;await s.cookies.set(item)}}catch(e){if(e.code!=='ENOENT')throw Error('This saved sign-in could not be unlocked. Reconnect the source.')}}
 const readList=async()=>{try{const v=JSON.parse(await fs.readFile(file,'utf8'));return Array.isArray(v)?v.filter(x=>typeof x==='string'&&x.startsWith('https://')).slice(0,100):[]}catch{return []}};
 async function remember(origin){const values=await readList();if(!values.includes(origin)){values.push(origin);await fs.writeFile(file,JSON.stringify(values),{mode:0o600})}}
 function isolate(origin){const partition=partitionFor(origin),s=session.fromPartition(partition);if(guarded.has(partition))return s;guarded.add(partition);
  s.setPermissionRequestHandler((_w,_p,cb)=>cb(false));s.setPermissionCheckHandler(()=>false);
  s.on('will-download',(event)=>event.preventDefault());
  const cache=new Map();s.webRequest.onBeforeRequest({urls:['http://*/*','https://*/*','file://*/*','ftp://*/*']},async(d,cb)=>{try{const u=new URL(d.url);if(u.protocol!=='https:'){cb({cancel:true});return}const until=cache.get(u.origin)||0;if(until<Date.now()){await validateSourceUrl(u.origin);cache.set(u.origin,Date.now()+30000)}cb({cancel:false})}catch{cb({cancel:true})}});
  return s;
 }
 async function make(url,visible){const {url:u}=await validateSourceUrl(url),s=isolate(u.origin);await restoreCookies(u.origin,s);const w=new BrowserWindow({title:'FRI source · '+u.hostname,width:1100,height:800,show:visible,autoHideMenuBar:false,webPreferences:{session:s,nodeIntegration:false,contextIsolation:true,sandbox:true,webSecurity:true,allowRunningInsecureContent:false,spellcheck:false}});windows.add(w);w.on('closed',()=>windows.delete(w));w.webContents.on('will-attach-webview',e=>e.preventDefault());
  w.webContents.setWindowOpenHandler(({url:next})=>{validateSourceUrl(next).then(()=>w.loadURL(next)).catch(()=>{});return {action:'deny'}});
  w.webContents.on('will-navigate',(e,to)=>{try{if(new URL(to).protocol!=='https:')e.preventDefault()}catch{e.preventDefault()}});
  w.webContents.on('did-navigate',(_e,to)=>{try{w.setTitle('FRI source · '+new URL(to).origin)}catch{}});
  return {w,s,origin:u.origin};
 }
 async function capture(w){const result=await w.webContents.executeJavaScript(READ_PAGE);const {url}=await validateSourceUrl(result.url);result.origin=url.origin;return result}
 async function ready(w){let previous='',stable=0,result;for(let i=0;i<12;i++){result=await capture(w);if(result.state==='sign-in')return result;if(result.text===previous)stable++;else stable=0;if(stable>=3)return result;previous=result.text;await new Promise(r=>setTimeout(r,250))}return result}
 const api={
  close(){for(const w of windows)w.destroy()},
  async list(){return (await readList()).map(origin=>({origin}))},
  async forget(origin){const url=new URL(origin);if(url.protocol!=='https:'||url.username||url.password)throw Error('Choose a connected HTTPS source.');const s=isolate(url.origin);for(const w of [...windows])if(w.webContents.session===s)w.close();await s.clearStorageData();await s.clearCache();await fs.unlink(cookieFile(url.origin)).catch(e=>{if(e.code!=='ENOENT')throw e});await fs.writeFile(file,JSON.stringify((await readList()).filter(v=>v!==url.origin)));return true},
  async read(input){
   const {url}=await validateSourceUrl(input);if(!(await readList()).includes(url.origin))return readPublicDetails(url.href);
   const {w,s}=await make(url.href,false);let timer;try{await Promise.race([w.loadURL(url.href),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Source loading timed out. Open it to finish loading.')),20000)})]);const result=await ready(w);if(result.state==='ready')await persistCookies(url.origin,s);return result}finally{clearTimeout(timer);w.destroy()}
  },
  async related(input){
   const first=await api.read(input);if(first.state!=='ready')return first;
   const pages=[first],seen=new Set([first.url]),queue=relatedLinks(first).map(link=>({...link,depth:1})),warnings=[];let size=first.text.length;
   while(queue.length&&pages.length<12&&size<120000){const link=queue.shift();if(seen.has(link.url))continue;seen.add(link.url);try{const page=await api.read(link.url);if(page.state!=='ready'){warnings.push('A linked page needs sign-in. Open that page to continue.');continue}pages.push(page);size+=page.text.length;if(link.depth<2)queue.push(...relatedLinks(page).filter(l=>/mod\/assign\/view/.test(l.url)).map(l=>({...l,depth:link.depth+1})))}catch{warnings.push('A linked page could not be read. Open it separately to retry.')}}
   if(queue.length)warnings.push('Some linked pages were not read in this batch. Import their links separately.');
   // A dashboard/course listing is navigation, not evidence that a class occurs at its enrolment dates.
   const specific=pages.filter(p=>/\/(calendar\/view|mod\/assign\/view)\.php$/.test(new URL(p.url).pathname));
   const selected=specific.length?specific:pages,text=selected.map(p=>'SOURCE PAGE: '+(p.title||'')+'\n'+p.text).join('\n\n');
   if(text.length>60000)warnings.push('Source text exceeded 60,000 characters. Import individual calendar pages for the remainder.');
   return {...first,text:text.slice(0,60000),pagesRead:pages.length,warnings};
  },
  async open(input){
   const {w,s,origin}=await make(input,true);
   return new Promise((resolve,reject)=>{let settled=false;
    const finish=value=>{if(settled)return;settled=true;resolve(value);w.close()};
    const use=async()=>{try{const result=await capture(w);if(result.state==='sign-in'){await dialog.showMessageBox(w,{type:'info',message:'Sign in on this website first.',detail:'FRI does not read password fields. Once your calendar or assignments are visible, choose Read this page.'});return}if(!result.text.trim()){await dialog.showMessageBox(w,{message:'This page has no readable calendar text yet.',detail:'Wait for it to load, or open the calendar/assignment page.'});return}await persistCookies(origin,s);await remember(origin);finish(result)}catch{await dialog.showMessageBox(w,{message:'This page could not be read or its session could not be saved.',detail:'Try a calendar page or export an ICS file from the service.'})}};
    w.setMenu(Menu.buildFromTemplate([{label:'Read this page',click:use},{label:'Back',click:()=>{if(w.webContents.navigationHistory.canGoBack())w.webContents.navigationHistory.goBack()}},{label:'Reload',click:()=>w.reload()},{label:'Show address',click:()=>dialog.showMessageBox(w,{message:'Current source',detail:w.webContents.getURL()})},{label:'Cancel import',click:()=>finish({state:'canceled'})}]));
    w.on('closed',()=>{if(!settled){settled=true;resolve({state:'canceled'})}});
    w.loadURL(input).catch(()=>{if(!settled&&!w.isDestroyed())dialog.showMessageBox(w,{message:'The site did not finish loading.',detail:'Reload or use an ICS export. Some services do not allow sign-in inside desktop browsers.'})});
   });
  }
 };return api;
}
module.exports={createSourceBrowser,partitionFor,READ_PAGE,relatedLinks};
