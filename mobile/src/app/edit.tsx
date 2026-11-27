import {useEffect,useRef,useState} from 'react';
import {Alert,Switch,TextInput,View} from 'react-native';
import {DateTimePickerAndroid} from '@react-native-community/datetimepicker';
import {router,useLocalSearchParams,usePreventRemove} from 'expo-router';
import {TimeWheel} from '../components/TimeWheel';
import {Page,Label,Button,Card} from '../components/ui';
import {useFri} from '../lib/store';
import {call,dateKey,FriEvent,localTime,shiftDay} from '../lib/fri';
import {getMeeting,clearMeeting} from '../lib/meeting';
export default function Edit(){
 const{id,date,meeting}=useLocalSearchParams<{id?:string;date?:string;meeting?:string}>();const{data,colors,refresh}=useFri();const original=data?.events.find(e=>e.id===id);const initialized=useRef(false);const suggestion=getMeeting(meeting);
 const[missing,setMissing]=useState({date:!!meeting&&!suggestion?.date,time:!!meeting&&!suggestion?.time,duration:!!meeting});
 const[wheel,setWheel]=useState<'start'|'end'|null>(null);const[touched,setTouched]=useState(false);
 const allowNavigation=usePreventRemove(touched,({repeat})=>{Alert.alert('Discard these changes?','',[{text:'Keep editing',style:'cancel'},{text:'Discard',style:'destructive',onPress:()=>{setTouched(false);clearMeeting(meeting);repeat()}}])});
 const[extras,setExtras]=useState(!!id);const[title,setTitle]=useState('');const[calendar,setCalendar]=useState('personal');const[allDay,setAllDay]=useState(false);const[start,setStart]=useState(`${date||dateKey()}T09:00`);const[end,setEnd]=useState(`${date||dateKey()}T10:00`);const[zone,setZone]=useState(Intl.DateTimeFormat().resolvedOptions().timeZone);const[location,setLocation]=useState('');const[notes,setNotes]=useState('');const[busy,setBusy]=useState(false);const[error,setError]=useState('');
 useEffect(()=>{if(original&&!initialized.current){initialized.current=true;setTitle(original.title);setCalendar(original.calendarId);setAllDay(original.allDay);setZone(original.zone);setLocation(original.location);setNotes(original.notes);setStart(original.allDay?`${original.startDate}T09:00`:localTime(original.startUtc,original.zone));setEnd(original.allDay?`${shiftDay(original.endDate,-1)}T10:00`:localTime(original.endUtc,original.zone))}},[original]);
 useEffect(()=>{if(suggestion&&!initialized.current){initialized.current=true;setTitle(suggestion.title);setLocation(suggestion.location||'');setNotes(suggestion.timeHint?`Confirm the time from the invitation: ${suggestion.timeHint}.`:'');const initial=`${suggestion.date||dateKey()}T${suggestion.time||'09:00'}`;setStart(initial);setEnd(initial)}},[suggestion]);
 function changeStart(value:string){setStart(value);if(!meeting){const span=Math.max(0,new Date(end).getTime()-new Date(start).getTime());if(span>0){const next=new Date(new Date(value).getTime()+span);setEnd(`${dateKey(next)}T${String(next.getHours()).padStart(2,'0')}:${String(next.getMinutes()).padStart(2,'0')}`)}}}
 function pick(which:'start'|'end',mode:'date'|'time'){if(mode==='time'){setWheel(which);return}const raw=which==='start'?start:end;DateTimePickerAndroid.open({value:new Date(raw),mode,is24Hour:data?.preferences.hourFormat==='24h',onValueChange:(_,value)=>{if(!value)return;setTouched(true);const result=mode==='date'?`${dateKey(value)}T${raw.slice(11)}`:`${raw.slice(0,10)}T${String(value.getHours()).padStart(2,'0')}:${String(value.getMinutes()).padStart(2,'0')}`;(which==='start'?changeStart:setEnd)(result);if(meeting){setMissing(m=>({...m,...(which==='start'?{[mode==='date'?'date':'time']:false,duration:true}:{duration:false})}));if(which==='start')setEnd(result)}}})}
 function duration(minutes:number){setTouched(true);const d=new Date(start);d.setMinutes(d.getMinutes()+minutes);setEnd(`${dateKey(d)}T${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`);setMissing(m=>({...m,duration:false}))}
 async function save(){if(busy)return;setBusy(true);setError('');try{
   if(meeting){if(!suggestion)throw Error('This draft expired. Share the invitation again.');if(missing.date||!allDay&&(missing.time||missing.duration))throw Error('Choose the date, time and duration before saving.');}
   const payload:Record<string,unknown>={...(original||{}),title,calendarId:calendar,allDay,zone,location,notes};
   if(allDay){payload.startDate=start.slice(0,10);payload.endDate=shiftDay(end.slice(0,10),1)}else{
    if(!original||original.allDay||start!==localTime(original.startUtc,original.zone)||zone!==original.zone)payload.startLocal=start;
    if(!original||original.allDay||end!==localTime(original.endUtc,original.zone)||zone!==original.zone)payload.endLocal=end;
   }
   const saved=await call<FriEvent>(meeting?'saveMeetingEvent':'saveEvent',payload);clearMeeting(meeting);await refresh();setTouched(false);allowNavigation();router.replace({pathname:'/event',params:{id:saved.id}})
 }catch(e){setError((e as Error).message)}finally{setBusy(false)}}
 const input={color:colors.ink,backgroundColor:colors.paper,borderColor:colors.control,borderWidth:1,borderRadius:16,padding:16,fontFamily:'BeVietnamPro',fontSize:17} as const;
 if(id&&data&&!original)return <Page><Label>This plan was removed.</Label><Button title="Back" onPress={()=>router.back()}/></Page>;
 return <Page>
 <Label large>{meeting?'Review plan':id?'Edit plan':'New plan'}</Label>
 {meeting&&suggestion?.relativeTime?<Label>“Later” needs an exact date and time.</Label>:null}
 {meeting&&suggestion?.timeHint?<Label>Confirm {suggestion.timeHint}: AM or PM?</Label>:null}
 <TextInput accessibilityLabel="Title" placeholder="Plan name" placeholderTextColor={colors.muted} value={title} onChangeText={value=>{setTouched(true);setTitle(value)}} maxLength={300} style={input}/>

 <View style={{flexDirection:'row',justifyContent:'space-between',alignItems:'center'}}><Label>All day</Label><Switch value={allDay} onValueChange={value=>{setTouched(true);setAllDay(value)}} trackColor={{true:colors.accent}}/></View>
 <Card><Label>{allDay?'First day':'Starts'}</Label><Button title={missing.date?'Choose a date':start.slice(0,10)} secondary onPress={()=>pick('start','date')}/>{!allDay?<Button title={missing.time?'Choose a time':start.slice(11)} secondary onPress={()=>pick('start','time')}/>:null}
 <Label>{allDay?'Last day (included)':'Ends'}</Label><Button title={missing.date?'Choose an end date':end.slice(0,10)} secondary onPress={()=>pick('end','date')}/>{!allDay?<Button title={missing.duration?'Choose an end time':end.slice(11)} secondary onPress={()=>pick('end','time')}/>:null}
 {meeting&&!allDay?<><Label>How long?</Label><View style={{flexDirection:'row',gap:8,flexWrap:'wrap'}}>{[30,60,90].map(n=><Button key={n} title={n+' min'} secondary disabled={missing.date||missing.time} onPress={()=>duration(n)}/>)}</View></>:null}</Card>
 <Button title={extras?'Fewer details':'Location & more'} secondary onPress={()=>setExtras(!extras)}/>{extras?<><Card><Label>Calendar</Label>{data?.calendars.map(c=><Button key={c.id} title={(calendar===c.id?'✓ ':'')+c.name} secondary onPress={()=>{setTouched(true);setCalendar(c.id)}}/>)}</Card>{!allDay?<><Label>Time zone</Label><TextInput accessibilityLabel="Time zone" value={zone} onChangeText={value=>{setTouched(true);setZone(value)}} autoCapitalize="none" style={input}/></>:null}
 <TextInput accessibilityLabel="Location" placeholder="Location" placeholderTextColor={colors.muted} value={location} onChangeText={value=>{setTouched(true);setLocation(value)}} style={input}/>
 <TextInput accessibilityLabel="Notes" placeholder="Notes" placeholderTextColor={colors.muted} value={notes} onChangeText={value=>{setTouched(true);setNotes(value)}} multiline style={[input,{minHeight:100,textAlignVertical:'top'}]}/>
 </>:null}
 {error?<Label>{error}</Label>:null}
 <Button title={busy?'Saving…':'Confirm'} disabled={busy||!title.trim()||!!meeting&&(missing.date||!allDay&&(missing.time||missing.duration))} onPress={()=>void save()}/>
 {wheel?<TimeWheel value={(wheel==='start'?start:end).slice(11)} onClose={()=>setWheel(null)} onConfirm={time=>{setTouched(true);const raw=wheel==='start'?start:end,result=`${raw.slice(0,10)}T${time}`;(wheel==='start'?changeStart:setEnd)(result);if(meeting){setMissing(m=>({...m,...(wheel==='start'?{time:false,duration:true}:{duration:false})}));if(wheel==='start')setEnd(result)}setWheel(null)}}/>:null}
 </Page>
}
