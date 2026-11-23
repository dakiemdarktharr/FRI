(function(root){
 'use strict';
 const day=d=>[d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');
 const validDate=s=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&day(new Date(s+'T12:00:00'))===s;
 const validTime=s=>typeof s==='string'&&/^([01]\d|2[0-3]):[0-5]\d$/.test(s);
 const minutes=s=>Number(s.slice(0,2))*60+Number(s.slice(3));
 const time=n=>String(Math.floor(n/60)).padStart(2,'0')+':'+String(n%60).padStart(2,'0');
 const shift=(s,n)=>{const d=new Date(s+'T12:00:00');d.setDate(d.getDate()+n);return day(d)};
 const stamp=(d,t)=>new Date(d+'T'+t+':00').getTime();
 const hash=s=>{let h=2166136261;for(const c of s){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return (h>>>0).toString(36)};
 const text=(s,n=160)=>typeof s==='string'?s.trim().slice(0,n):'';
 function normalize(raw){
  const n=(v,max)=>Number.isInteger(v)&&v>0&&v<=max?v:0;
  return {title:text(raw.title),kind:['schedule','deadline','task'].includes(raw.kind)?raw.kind:'',date:validDate(raw.date)?raw.date:'',time:validTime(raw.time)?raw.time:'',duration:n(raw.duration,1440),dueDate:validDate(raw.dueDate)?raw.dueDate:'',dueTime:validTime(raw.dueTime)?raw.dueTime:'',effortMinutes:n(raw.effortMinutes,525600),leadDays:n(raw.leadDays,366),periods:n(raw.periods,30),periodMinutes:n(raw.periodMinutes,180),weekdays:[...new Set((Array.isArray(raw.weekdays)?raw.weekdays:[]).filter(v=>Number.isInteger(v)&&v>=0&&v<7))],repeatFrom:validDate(raw.repeatFrom)?raw.repeatFrom:'',repeatUntil:validDate(raw.repeatUntil)?raw.repeatUntil:'',location:text(raw.location,200),evidence:text(raw.evidence,1200),sourceKey:text(raw.sourceKey,220),notes:text(raw.notes,1000),allDay:raw.allDay===true};
 }
 function missing(r){
  if(!r.title)return ['title','What is this plan called?'];
  if(!r.kind)return ['kind','Is this a schedule or a one-time task?'];
  if(r.kind==='task'||r.kind==='deadline'){
   if(!r.dueDate)return ['dueDate','What is the deadline date?'];
   if(!r.dueTime)return ['dueTime','What time is it due?'];
   if(r.kind==='task'&&!r.effortMinutes)return ['effortMinutes','How many minutes of work will it take?'];
   if(r.kind==='task'&&!r.leadDays)return ['leadDays','How many days before the deadline should work begin?'];
  }else{
   if(r.weekdays.length){if(!r.repeatFrom)return ['repeatFrom','When does this timetable begin?'];if(!r.repeatUntil)return ['repeatUntil','When does this timetable end?'];}
   else if(!r.date)return ['date','Which date is this for?'];
   if(!r.time)return ['time','What time does it start?'];
   if(!r.duration){if(r.periods&&!r.periodMinutes)return ['periodMinutes','How long is one teaching period, in minutes?'];return ['duration','How many minutes does it last?'];}
  }
  return null;
 }
 function key(t){return [t.title.trim().normalize('NFKC').toLowerCase(),t.date,t.time,t.kind||'schedule'].join('|')}
 function past(r,now=Date.now()){
  if(r.kind==='task'||r.kind==='deadline')return validDate(r.dueDate)&&(r.dueTime?stamp(r.dueDate,r.dueTime)<=now:r.dueDate<day(new Date(now)));
  if(r.weekdays.length)return !!r.repeatUntil&&r.repeatUntil<day(new Date(now));
  return validDate(r.date)&&(r.time&&r.duration?stamp(r.date,r.time)+r.duration*60000<=now:r.date<day(new Date(now)));
 }
 function task(r,date,at,duration,kind='schedule',suffix=''){
  return {id:'import-'+hash([r.sourceKey||r.title,date,at,kind,suffix].join('|')),sourceKey:(r.sourceKey||'source-'+hash(r.title+'|'+r.evidence))+':'+date+':'+at+':'+kind+suffix,title:r.title,date,time:at,duration,kind,allDay:r.allDay,category:r.kind==='task'?'Work':'Personal',location:r.location,notes:text((r.notes?r.notes+'\n':'')+(r.evidence?'Source: '+r.evidence:''),2000),done:false};
 }
 function overlap(a,b){return a.date===b.date&&a.duration>0&&b.duration>0&&minutes(a.time)<minutes(b.time)+b.duration&&minutes(b.time)<minutes(a.time)+a.duration}
 function plan(input,existing=[],options={}){
  const now=options.now??Date.now(),today=day(new Date(now)),workStart=options.workStart??540,workEnd=options.workEnd??1080,chunk=options.sessionMinutes??60,breakMinutes=options.breakMinutes??10;
  if(!(Number.isInteger(workStart)&&Number.isInteger(workEnd)&&workStart>=0&&workEnd<=1440&&workStart<workEnd&&Number.isInteger(chunk)&&chunk>=15&&chunk<=240&&Number.isInteger(breakMinutes)&&breakMinutes>=0&&breakMinutes<=120))throw Error('Choose a valid work window and session length.');
  const rows=input.map(normalize),tasks=[],skipped=[],issues=[],conflicts=[],keys=new Set(existing.map(key)),sources=new Set(existing.filter(t=>t.sourceKey).map(t=>t.sourceKey));
  const add=t=>{if(keys.has(key(t))||sources.has(t.sourceKey)){skipped.push({title:t.title,reason:'Already on your calendar'});return false}keys.add(key(t));sources.add(t.sourceKey);tasks.push(t);return true};
  const pending=[],reservedBreaks=[];
  for(const r of rows){
   if(past(r,now)){skipped.push({title:r.title,reason:'Already past'});continue}
   const m=missing(r);if(m){issues.push({row:r,field:m[0],reason:m[1]});continue}
   if(r.kind==='task'){pending.push(r);continue}
   if(r.kind==='deadline'){add(task(r,r.dueDate,r.dueTime,0,'deadline'));continue}
   let dates=[r.date];
   if(r.weekdays.length){
    if(r.repeatUntil<r.repeatFrom){issues.push({row:r,field:'repeatUntil',reason:'End date must be on or after the start.'});continue}
    if((new Date(r.repeatUntil+'T12:00:00')-new Date(r.repeatFrom+'T12:00:00'))/86400000>366){issues.push({row:r,field:'repeatUntil',reason:'Import one academic year at a time.'});continue}
    dates=[];for(let d=r.repeatFrom;d<=r.repeatUntil;d=shift(d,1))if(r.weekdays.includes(new Date(d+'T12:00:00').getDay()))dates.push(d);
   }
   for(const d of dates){if(stamp(d,r.time)+r.duration*60000<=now){skipped.push({title:r.title,reason:'Already past'});continue}
    // Split overnight blocks at local midnight, retaining a shared series identity.
    let left=r.duration,date=d,start=minutes(r.time);while(left){const take=Math.min(left,1440-start);const t=task(r,date,time(start),take);t.seriesKey=r.sourceKey||'series-'+hash(r.title+'|'+r.time);if(stamp(date,time(start))+take*60000>now)add(t);else skipped.push({title:r.title,reason:'Already past'});left-=take;date=shift(date,1);start=0;}
   }
  }
  pending.sort((a,b)=>stamp(a.dueDate,a.dueTime)-stamp(b.dueDate,b.dueTime)||b.effortMinutes-a.effortMinutes||a.title.localeCompare(b.title));
  for(const r of pending){
   const deadline=task(r,r.dueDate,r.dueTime,0,'deadline');if(keys.has(key(deadline))||sources.has(deadline.sourceKey)){skipped.push({title:r.title,reason:'Already on your calendar'});continue}
   const due=stamp(r.dueDate,r.dueTime),first=shift(r.dueDate,-r.leadDays),blocks=[],occupied=[...existing,...tasks,...reservedBreaks];let left=r.effortMinutes;
   for(let date=first<today?today:first;date<=r.dueDate&&left>0;date=shift(date,1)){
    let at=Math.max(workStart,date===today?Math.ceil((new Date(now).getHours()*60+new Date(now).getMinutes()+1)/5)*5:0),end=Math.min(workEnd,date===r.dueDate?minutes(r.dueTime):1440);
    const busy=occupied.filter(t=>t.date===date&&t.duration>0).map(t=>[minutes(t.time),minutes(t.time)+t.duration]).sort((a,b)=>a[0]-b[0]);
    while(at<end&&left>0){const hit=busy.find(([a,b])=>b>at&&a<=at);if(hit){at=hit[1];continue}const next=busy.find(([a])=>a>at),gap=Math.min(end,next?.[0]??end)-at,take=Math.min(chunk,left,gap);
     if(take<Math.min(15,left)){at=next?next[1]:end;continue}
     const t=task(r,date,time(at),take,'schedule',':work-'+blocks.length);t.title=text(r.title+' · Work '+(blocks.length+1));t.assignmentKey=deadline.sourceKey;t.dueDate=r.dueDate;t.dueTime=r.dueTime;blocks.push(t);left-=take;at+=take+breakMinutes;
    }
   }
   if(left){issues.push({row:r,field:'effortMinutes',reason:'Not enough free time before the deadline: '+left+' minutes remain. Increase lead days, widen work hours or reduce the estimate.'});continue}
   if(blocks.some(t=>stamp(t.date,t.time)+t.duration*60000>due))throw Error('Planning invariant failed');
   add(deadline);blocks.forEach(t=>{if(add(t)&&breakMinutes){const at=minutes(t.time)+t.duration;if(at<1440)reservedBreaks.push({date:t.date,time:time(at),duration:Math.min(breakMinutes,1440-at)});}});
  }
  tasks.sort((a,b)=>a.date.localeCompare(b.date)||a.time.localeCompare(b.time)||a.title.localeCompare(b.title));
  tasks.forEach((t,i)=>{for(const other of [...existing,...tasks.slice(0,i)])if(overlap(t,other))conflicts.push({task:t,other})});
  return {tasks,skipped,issues,conflicts};
 }
 function plain(source){return String(source).split(/\r?\n/).filter(s=>s.trim()).map(line=>{const dates=line.match(/\d{4}-\d{2}-\d{2}/g)||[],times=line.match(/\b(?:[01]\d|2[0-3]):[0-5]\d\b/g)||[],kind=/deadline|due|assignment|hạn nộp|bài tập/i.test(line)?'task':'schedule',duration=line.match(/(\d+)\s*(?:min|minutes|phút)/i)?.[1],hours=line.match(/(\d+(?:\.\d+)?)\s*(?:hours?|giờ)/i)?.[1],days=line.match(/(\d+)\s*(?:days?|ngày)/i)?.[1];return normalize({title:line.replace(/\d{4}-\d{2}-\d{2}|\b\d{2}:\d{2}\b|\b\d+(?:\.\d+)?\s*(?:minutes?|min|hours?|days?)\b/gi,'').replace(/\b(?:due|deadline|assignment)\b/gi,'').trim(),kind,date:kind==='schedule'?dates[0]:'',time:kind==='schedule'?times[0]:'',duration:times.length>1?((minutes(times[1])-minutes(times[0])+1440)%1440):Number(duration||hours*60)||0,dueDate:kind==='task'?dates[0]:'',dueTime:kind==='task'?times[0]:'',effortMinutes:Number(duration||hours*60)||0,leadDays:Number(days)||0,evidence:line})})}
 const api={normalize,missing,past,plan,plain,day,shift,validDate,validTime,stamp,key,hash};if(typeof module==='object')module.exports=api;else root.FriImport=api;
})(typeof window==='undefined'?globalThis:window);
