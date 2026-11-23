import ICAL from 'ical.js';
const localDate=d=>[d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');
const localTime=d=>String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0');
function instant(t,zone){
 if(t.isDate)return new Date(t.year,t.month-1,t.day);
 if(!zone||zone==='floating'||zone==='local')return new Date(t.year,t.month-1,t.day,t.hour,t.minute,t.second);
 if(t.zone.tzid!=='floating')return t.toJSDate();
 // An ICS may reference an IANA zone without embedding VTIMEZONE.
 const target=Date.UTC(t.year,t.month-1,t.day,t.hour,t.minute,t.second),formatter=new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'});let value=target;
 for(let i=0;i<4;i++){const p=Object.fromEntries(formatter.formatToParts(new Date(value)).map(v=>[v.type,v.value])),shown=Date.UTC(+p.year,+p.month-1,+p.day,+p.hour,+p.minute,+p.second),difference=target-shown;if(!difference)return new Date(value);value+=difference}
 throw Error('The source includes a nonexistent local time. Confirm it manually.');
}
export function parseCalendar(text,{from=new Date(),until=new Date(Date.now()+180*86400000)}={}){
 const root=new ICAL.Component(ICAL.parse(text));for(const zone of root.getAllSubcomponents('vtimezone'))ICAL.TimezoneService.register(new ICAL.Timezone(zone));
 const rows=[],warnings=[],components=root.getAllSubcomponents('vevent'),exceptions=components.filter(c=>c.hasProperty('recurrence-id'));
 const masters=components.filter(c=>!c.hasProperty('recurrence-id'));
 const read=(event,start,end,component,identity)=>{
  if(String(component.getFirstPropertyValue('status')).toUpperCase()==='CANCELLED')return;
  const zone=component.getFirstProperty('dtstart')?.getParameter('tzid')||start.zone.tzid;
  try{const a=instant(start,zone),b=end?instant(end,zone):null;if(b&&+b<=+from)return;const duration=b?Math.round((b-a)/60000):0;
   const base={title:event.summary||'Untitled event',kind:'schedule',allDay:start.isDate,location:event.location||'',notes:event.description||'',evidence:'ICS · '+(event.summary||'')+' · '+start.toString()+(end?' → '+end.toString():'')};
   if(!b||b<=a){if(a>=from)rows.push({...base,date:localDate(a),time:localTime(a),duration:0,sourceKey:'ics:'+event.uid+':'+identity});return}
   for(let cursor=new Date(a);cursor<b;){const midnight=new Date(cursor.getFullYear(),cursor.getMonth(),cursor.getDate()+1),finish=new Date(Math.min(+midnight,+b));
    if(finish>from){const at=cursor.getHours()*60+cursor.getMinutes(),last=+finish===+midnight?1440:finish.getHours()*60+finish.getMinutes();rows.push({...base,date:localDate(cursor),time:start.isDate?'00:00':localTime(cursor),duration:start.isDate?1440:last-at,sourceKey:'ics:'+event.uid+':'+identity+':'+localDate(cursor)})}
    cursor=finish;
   }
  }catch(e){warnings.push(e.message)}
 };
 for(const c of [...masters,...exceptions.filter(ex=>!masters.some(m=>m.getFirstPropertyValue('uid')===ex.getFirstPropertyValue('uid')))]){const event=new ICAL.Event(c);if(!event.startDate){warnings.push('An event has no start date.');continue}for(const ex of exceptions.filter(ex=>ex!==c&&ex.getFirstPropertyValue('uid')===event.uid))event.relateException(new ICAL.Event(ex));
  if(event.isRecurring()){const it=event.iterator();let occurrence,steps=0;while((occurrence=it.next())){if(++steps>50000)throw Error('This recurrence is too large. Export a smaller date range.');if(occurrence.year>until.getFullYear()+1)break;const detail=event.getOccurrenceDetails(occurrence),item=detail.item;const zone=item.component.getFirstProperty('dtstart')?.getParameter('tzid')||detail.startDate.zone.tzid;if(+instant(detail.startDate,zone)>+until)break;read(item,detail.startDate,detail.endDate,item.component,occurrence.toString());if(rows.length>5000)throw Error('Choose a smaller calendar range.')}warnings.push('Repeating calendar expanded through '+localDate(until)+'. Import again to extend it.');}
  else read(event,event.startDate,event.endDate,c,event.startDate.toString());
 }
 for(const c of root.getAllSubcomponents('vtodo')){if(['COMPLETED','CANCELLED'].includes(String(c.getFirstPropertyValue('status')).toUpperCase()))continue;const due=c.getFirstPropertyValue('due');if(!due){rows.push({title:c.getFirstPropertyValue('summary')||'',kind:'task',evidence:'ICS task missing due date'});continue}const d=instant(due,c.getFirstProperty('due')?.getParameter('tzid')||due.zone.tzid);rows.push({title:c.getFirstPropertyValue('summary')||'',kind:'task',dueDate:localDate(d),dueTime:due.isDate?'':localTime(d),effortMinutes:0,leadDays:0,sourceKey:'ics:'+c.getFirstPropertyValue('uid'),evidence:'ICS task · '+due.toString()})}
 return {events:rows,warnings};
}
if(typeof window!=='undefined')window.FriCalendarSource={parseCalendar};
