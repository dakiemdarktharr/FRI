/* Shared deterministic planner. No network, model output, or calendar writes. */
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.FriDayCore=factory()})(typeof globalThis!=='undefined'?globalThis:this,function(){
 'use strict';
 const clone=value=>JSON.parse(JSON.stringify(value));
 const dateKey=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
 const minute=time=>Number(time.slice(0,2))*60+Number(time.slice(3));
 const clock=n=>`${String(Math.floor(n/60)).padStart(2,'0')}:${String(n%60).padStart(2,'0')}`;
 function hash(value){let a=2166136261,b=5381;for(let i=0;i<value.length;i++){a=Math.imul(a^value.charCodeAt(i),16777619);b=Math.imul(b,33)^value.charCodeAt(i)}return (a>>>0).toString(36)+(b>>>0).toString(36)}
 function valid(t){if(!t||typeof t.id!=='string'||!/^[a-zA-Z0-9_-]{1,100}$/.test(t.id)||typeof t.title!=='string'||!t.title.trim()||t.title.length>160||!/^\d{4}-\d{2}-\d{2}$/.test(t.date)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(t.time)||!Number.isInteger(t.duration)||t.duration<0||minute(t.time)+t.duration>1440)return false;const date=new Date(t.date+'T12:00:00Z');return Number.isFinite(+date)&&date.toISOString().slice(0,10)===t.date}
 const start=t=>+new Date(t.date+'T'+t.time+':00');
 const imported=t=>Object.prototype.hasOwnProperty.call(t,'sourceKey')||Boolean(t.sourceId||t.imported||t.allDay);
 const validLimit=t=>t.flexibleUntil===undefined||(typeof t.flexibleUntil==='string'&&/^([01]\d|2[0-3]):[0-5]\d$/.test(t.flexibleUntil));
 const movable=(t,now)=>t.flexible===true&&validLimit(t)&&!imported(t)&&!t.done&&t.kind!=='deadline'&&t.duration>0&&start(t)>=+now;
 function fingerprint(state){return hash(JSON.stringify((state?.tasks||[]).map(t=>[t.id,t.title,t.date,t.time,t.duration,t.kind,!!t.done,t.flexible===true,t.flexibleUntil??null,Object.prototype.hasOwnProperty.call(t,'sourceKey'),t.sourceKey||'',t.sourceId||'',!!t.imported,!!t.allDay]).sort((a,b)=>String(a[0]).localeCompare(String(b[0])))))}
 function freeSlot(task,tasks,now){
  // Preserve the date and duration. Day never moves fixed appointments or guesses travel time.
  if(tasks.some(t=>t.id!==task.id&&!t.done&&t.date===task.date&&t.allDay))return null;
  const end=Math.min(1080,task.flexibleUntil===undefined?1080:minute(task.flexibleUntil));
  let from=540;if(task.date===dateKey(now))from=Math.max(from,Math.ceil((now.getHours()*60+now.getMinutes()+now.getSeconds()/60+now.getMilliseconds()/60000)/15)*15);
  const busy=tasks.filter(t=>t.id!==task.id&&!t.done&&t.kind!=='deadline'&&t.duration>0&&t.date===task.date).map(t=>[minute(t.time),minute(t.time)+t.duration]).sort((a,b)=>a[0]-b[0]);
  for(const [a,b] of busy){if(b<=from)continue;if(from+task.duration<=a)break;from=Math.max(from,b)}
  return from+task.duration<=end?clock(from):null;
 }
 function analyze(state,now=new Date()){
  now=new Date(now);if(!Number.isFinite(+now))throw Error('Invalid Day clock');
  const tasks=Array.isArray(state?.tasks)?state.tasks.filter(valid):[],today=dateKey(now),limit=new Date(now);limit.setDate(limit.getDate()+7);const until=dateKey(limit);
  const dismissed=new Set(Array.isArray(state?.settings?.dayDismissed)?state.settings.dayDismissed.filter(id=>typeof id==='string').slice(-100):[]);
  const active=tasks.filter(t=>!t.done&&t.date>=today&&t.date<until).sort((a,b)=>start(a)-start(b)||a.id.localeCompare(b.id));
  const candidates=[];
  for(const t of active){const remaining=start(t)-+now;if(t.kind==='deadline'&&remaining>=0&&remaining<=86400000){candidates.push({id:'due-'+hash(JSON.stringify([t.id,t.title,t.date,t.time])),type:'deadline',title:'Deadline sắp tới',body:`${t.title} · ${t.date} lúc ${t.time}.`,evidenceIds:[t.id],priority:remaining<=3600000?0:2,at:start(t)})}}
  const scheduled=active.filter(t=>t.kind!=='deadline'&&t.duration>0&&start(t)+t.duration*60000>+now);let found=0;
  outer:for(let i=0;i<scheduled.length;i++){const a=scheduled[i];for(let j=i+1;j<scheduled.length;j++){const b=scheduled[j];if(b.date!==a.date||minute(b.time)>=minute(a.time)+a.duration)break;
    let move;for(const t of [a,b]){if(!movable(t,now))continue;const time=freeSlot(t,tasks,now);if(time&&time!==t.time){move={taskId:t.id,date:t.date,time,fromDate:t.date,fromTime:t.time};break}}
    const pair=[a.id,b.id].sort(),id='overlap-'+hash(JSON.stringify([pair,a.title,b.title,a.date,a.time,a.duration,b.time,b.duration,move||null]));
    if(dismissed.has(id))continue;if(++found>32)break outer;
    const moving=move&&tasks.find(t=>t.id===move.taskId);
    candidates.push({id,type:'conflict',title:'Hai lịch đang trùng nhau',body:`${a.title} (${a.time}) và ${b.title} (${b.time}) · ${a.date}. ${move?`Có thể dời ${moving.title} sang ${move.time}, giữ nguyên thời lượng.`:'Chưa có việc linh hoạt với khung trống phù hợp trong 09:00–18:00 cùng ngày.'}`,evidenceIds:pair,...(move?{move}:{}),priority:start(a)-+now<=3600000?0:1,at:Math.max(+now,Math.min(start(a),start(b)))})
  }}
  candidates.sort((a,b)=>a.priority-b.priority||a.at-b.at||a.id.localeCompare(b.id));
  return {cards:candidates.filter(c=>!dismissed.has(c.id)).slice(0,8),fingerprint:fingerprint(state)};
 }
 function applyMove(state,request,now=new Date()){
  const current=analyze(state,now);if(!request||typeof request.id!=='string'||request.fingerprint!==current.fingerprint)throw Error('Lịch đã thay đổi. Hãy xem gợi ý mới của Day.');
  const card=current.cards.find(c=>c.id===request.id);if(!card?.move)throw Error('Gợi ý này đã hết hiệu lực hoặc không thể áp dụng.');
  const next=clone(state),task=next.tasks.find(t=>t.id===card.move.taskId);task.date=card.move.date;task.time=card.move.time;return next;
 }
 return {analyze,applyMove,fingerprint};
});
