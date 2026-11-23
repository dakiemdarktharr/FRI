'use strict';
const fs=require('node:fs/promises'),path=require('node:path');
const clone=x=>JSON.parse(JSON.stringify(x));
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
function validate(s){
 if(!s||s.version!==1||!Array.isArray(s.tasks)||s.tasks.length>10000||!s.settings||JSON.stringify(s).length>8*1024*1024)throw Error('Invalid calendar');
 const checkKeys=o=>{if(o&&typeof o==='object')for(const key of Object.keys(o)){if(['__proto__','constructor','prototype'].includes(key))throw Error('Invalid calendar field');checkKeys(o[key])}};checkKeys(s);
 const ids=new Set();for(const t of s.tasks){
  if(!t||typeof t.id!=='string'||!/^[a-zA-Z0-9_-]{1,100}$/.test(t.id)||ids.has(t.id)||typeof t.title!=='string'||!t.title.trim()||t.title.length>160||!/^\d{4}-\d{2}-\d{2}$/.test(t.date)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(t.time)||!Number.isInteger(t.duration)||t.duration<0||t.duration>1440)throw Error('Invalid appointment');
  const d=new Date(t.date+'T12:00:00Z');if(t.kind==='deadline'&&t.duration!==0)throw Error('Invalid deadline');const [hour,minute]=t.time.split(':').map(Number);if(hour*60+minute+t.duration>1440)throw Error('Appointment crosses midnight');
  if(t.flexibleUntil!==undefined&&(typeof t.flexibleUntil!=='string'||!/^([01]\d|2[0-3]):[0-5]\d$/.test(t.flexibleUntil)))throw Error('Invalid flexible time limit');
  if(!Number.isFinite(+d)||d.toISOString().slice(0,10)!==t.date)throw Error('Invalid date');
  for(const [key,max] of [['category',35],['location',200],['notes',2000]])if(typeof t[key]!=='string'||t[key].length>max)throw Error('Invalid appointment details');
  ids.add(t.id);
 }
 return clone(s);
}
// Apply only fields edited by the sender. A widget completion cannot be lost to
// an unrelated settings save in the main window.
function merge(current,base,next){
 if(!current)return validate(next);const result=clone(current);
 for(const k of Object.keys(next)){
  if(k==='tasks')continue;
  if(k==='settings'){for(const key of Object.keys(next.settings))if(!same(base?.settings?.[key],next.settings[key]))result.settings[key]=clone(next.settings[key]);}
  else if(!same(base?.[k],next[k]))result[k]=clone(next[k]);
 }
 const old=new Map((base?.tasks||[]).map(t=>[t.id,t])),incoming=new Map(next.tasks.map(t=>[t.id,t]));
 result.tasks=result.tasks.filter(t=>!old.has(t.id)||incoming.has(t.id));
 for(const task of next.tasks){const before=old.get(task.id),existing=result.tasks.find(t=>t.id===task.id);if(!before){if(!existing)result.tasks.push(clone(task));continue}if(!existing)continue;for(const key of Object.keys(task))if(!same(before[key],task[key]))existing[key]=clone(task[key]);}
 return validate(result);
}
function createStore(directory,crypto){
 const file=path.join(directory,'calendar.v1.encrypted');let state=null,revision=0,queue=Promise.resolve();
 return {
  async init(){await fs.mkdir(directory,{recursive:true});if(!await crypto.isAsyncEncryptionAvailable())throw Error('Secure storage is unavailable. Unlock your system keychain and reopen FRI.');try{const bytes=await fs.readFile(file);const decrypted=await crypto.decryptStringAsync(bytes);const data=JSON.parse(decrypted.result);if(decrypted.shouldReEncrypt){const rotated=await crypto.encryptStringAsync(decrypted.result);await fs.writeFile(file+'.pending',rotated,{mode:0o600});await fs.rename(file+'.pending',file);}state=validate(data.state);revision=data.revision||0;}catch(e){if(e.code!=='ENOENT')throw Error('Your calendar could not be unlocked. It has not been overwritten.');}return this.read()},
  read(){return {state:state&&clone(state),revision}},
  commit(base,next){const operation=queue.then(async()=>{validate(next);const updated=merge(state,base,next),data=await crypto.encryptStringAsync(JSON.stringify({state:updated,revision:revision+1}));const temp=file+'.pending';await fs.writeFile(temp,data,{mode:0o600});await fs.rename(temp,file);state=updated;revision++;return this.read()});queue=operation.catch(()=>{});return operation},
  // Recompute an action against the latest state inside the same write queue.
  // A calendar edit queued before Day cannot be overwritten by a stale suggestion.
  transaction(update){const operation=queue.then(async()=>{const updated=validate(update(state&&clone(state))),data=await crypto.encryptStringAsync(JSON.stringify({state:updated,revision:revision+1}));const temp=file+'.pending';await fs.writeFile(temp,data,{mode:0o600});await fs.rename(temp,file);state=updated;revision++;return this.read()});queue=operation.catch(()=>{});return operation},
  settled(){return queue}
 };
}
module.exports={createStore,validate,merge};
