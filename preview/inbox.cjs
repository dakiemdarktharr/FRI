(function(root){
 'use strict';
 const F=typeof module==='object'?require('./import-plan.cjs'):root.FriImport;
 const overlap=(a,b)=>a.date===b.date&&a.duration>0&&b.duration>0&&F.stamp(a.date,a.time)<F.stamp(b.date,b.time)+b.duration*60000&&F.stamp(b.date,b.time)<F.stamp(a.date,a.time)+a.duration*60000;
 function conflictIds(tasks){
  const groups=new Map(),ids=new Set();
  for(const task of tasks){if(!(task.duration>0))continue;if(!groups.has(task.date))groups.set(task.date,[]);groups.get(task.date).push(task)}
  for(const group of groups.values()){
   group.sort((a,b)=>a.time.localeCompare(b.time));let furthest=-Infinity,owner;
   for(const task of group){const start=F.stamp(task.date,task.time),end=start+task.duration*60000;if(start<furthest){ids.add(task.id);ids.add(owner)}if(end>furthest){furthest=end;owner=task.id}}
  }
  return ids;
 }
 // Dates are never guessed. Unsupported prose is left for the explicit fallback.
 function parse(text,name=''){
  const input=String(text).trim();let raw;
  if(/\.json$/i.test(name)||/^[\[{]/.test(input)){
   try{const value=JSON.parse(input);raw=Array.isArray(value)?value:value.events||value.appointments;if(!Array.isArray(raw))throw Error();return {rows:raw.slice(0,500).map(F.normalize),method:'JSON',warnings:raw.length>500?['Only the first 500 plans were read.']:[]}}catch{if(/\.json$/i.test(name))throw Error('Choose a JSON array of appointments or an object with an events array.');}
  }
  if(/\.csv$/i.test(name)){
   const table=[];let row=[],cell='',quoted=false;
   for(let i=0;i<=input.length;i++){const c=input[i];if(c==='"'){if(quoted&&input[i+1]==='"'){cell+='"';i++}else quoted=!quoted}else if(!quoted&&(c===','||c==='\n'||c===undefined)){row.push(cell.replace(/\r$/,''));cell='';if(c!==','){table.push(row);row=[]}}else cell+=c;}
   if(quoted)throw Error('This CSV has an unclosed quoted field.');const headers=table.shift().map(h=>h.trim());
   if(!headers.includes('title'))throw Error('CSV needs a title column. Use date, time, duration and kind for scheduling.');
   raw=table.filter(r=>r.some(Boolean)).map(cells=>{const item={};headers.forEach((h,i)=>{if(['title','kind','date','time','duration','dueDate','dueTime','effortMinutes','leadDays','location','notes'].includes(h))item[h]=['duration','effortMinutes','leadDays'].includes(h)?Number(cells[i]):cells[i]});return item});
   return {rows:raw.slice(0,500).map(F.normalize),method:'CSV',warnings:raw.length>500?['Only the first 500 plans were read.']:[]};
  }
  const lines=input.split(/\r?\n/).filter(s=>/\d{4}-\d{2}-\d{2}/.test(s)&&(/\b\d{1,2}:\d{2}\b/.test(s)||/deadline|due|assignment|hạn nộp|bài tập/i.test(s)));
  const rows=F.plain(lines.join('\n')).filter(r=>r.title);
  return {rows:rows.slice(0,500),method:'Text',warnings:rows.length>500?['Only the first 500 plans were read.']:[]};
 }
 function prepare(batches,existing,options={}){
  const records=batches.flatMap(b=>(b.rows||[]).map((r,i)=>({batch:b.id,settings:{...options,...b.settings},row:F.normalize({...r,sourceKey:r.sourceKey||'inbox-'+b.id+'-'+i})}))),accepted=[],held=new Map(),skipped=[];
  const hold=(entry,reason)=>{const key=entry.batch+'|'+entry.row.sourceKey;const old=held.get(key);held.set(key,{...entry,reasons:[...new Set([...(old?.reasons||[]),reason])]})};
  // Fixed rows are resolved before flexible work, so work never displaces a class.
  for(const entry of records.filter(e=>e.row.kind!=='task')){
   const result=F.plan([entry.row],[...existing,...accepted],entry.settings);skipped.push(...result.skipped);result.issues.forEach(i=>hold(entry,i.reason));
   for(const t of result.tasks){const collision=[...existing,...accepted].find(other=>overlap(t,other));if(collision)hold(entry,t.date+' '+t.time+' overlaps '+collision.title);else accepted.push(t)}
  }
  const flexible=records.filter(e=>e.row.kind==='task').sort((a,b)=>F.stamp(a.row.dueDate,a.row.dueTime)-F.stamp(b.row.dueDate,b.row.dueTime)),breaks=[];
  for(const entry of flexible){const result=F.plan([entry.row],[...existing,...accepted,...breaks],entry.settings);accepted.push(...result.tasks);skipped.push(...result.skipped);result.issues.forEach(i=>hold(entry,i.reason));for(const t of result.tasks.filter(t=>t.assignmentKey)){const end=F.stamp(t.date,t.time)+t.duration*60000,d=new Date(end),minutes=d.getHours()*60+d.getMinutes(),rest=Math.min(entry.settings.breakMinutes??10,1440-minutes);if(rest&&F.day(d)===t.date)breaks.push({title:'Break',date:t.date,time:String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0'),duration:rest})}}
  const remaining=batches.map(b=>({...b,rows:[...held.values()].filter(e=>e.batch===b.id).map(e=>({...e.row,holdReasons:e.reasons})),status:'attention'})).filter(b=>b.rows.length);
  accepted.sort((a,b)=>a.date.localeCompare(b.date)||a.time.localeCompare(b.time));
  return {tasks:accepted,remaining,held:[...held.values()],skipped};
 }
 const api={parse,prepare,overlap,conflictIds};if(typeof module==='object')module.exports=api;else root.FriInbox=api;
})(typeof window==='undefined'?globalThis:window);
