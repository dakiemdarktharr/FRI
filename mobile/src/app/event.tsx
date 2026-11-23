import {Alert} from 'react-native';
import {router,useLocalSearchParams} from 'expo-router';
import {Page,Label,Button,Card} from '../components/ui';
import {useFri} from '../lib/store';
import {call,shiftDay} from '../lib/fri';

export default function Detail(){
 const{id}=useLocalSearchParams<{id:string}>();const{data,refresh}=useFri();
 const event=data?.events.find(item=>item.id===id);
 if(!data)return <Page><Label>Loading…</Label></Page>;
 if(!event)return <Page><Label>This plan is no longer available.</Label><Button title="Back to Today" onPress={()=>router.replace('/')}/></Page>;
 const format=data.preferences.hourFormat;
 const dateTime=new Intl.DateTimeFormat(undefined,{timeZone:event.zone,dateStyle:'medium',timeStyle:'short',...(format==='system'?{}:{hour12:format==='12h'})});
 const lastDay=event.allDay?shiftDay(event.endDate,-1):'';
 const remove=()=>Alert.alert('Delete this plan?','This removes it from this device and your Fri widgets.',[
  {text:'Cancel'},
  {text:'Delete',style:'destructive',onPress:()=>void call('deleteEvent',{id}).then(()=>{void refresh();router.replace('/')}).catch(error=>Alert.alert('Could not delete',error.message))},
 ]);
 return <Page><Label large>{event.title}</Label><Card>
  {event.allDay?<><Label>All day</Label><Label>{event.startDate}{lastDay!==event.startDate?` – ${lastDay}`:''}</Label></>:<>
   <Label>Starts · {dateTime.format(event.startUtc)}</Label>
   <Label>Ends · {dateTime.format(event.endUtc)}</Label>
   <Label muted>{event.zone}</Label>
  </>}
  <Label muted>{data.calendars.find(calendar=>calendar.id===event.calendarId)?.name}</Label>
  {event.location?<Label>{event.location}</Label>:null}
  {event.notes?<Label>{event.notes}</Label>:null}
 </Card><Button title={event.done?'Completed':'Mark done'} disabled={event.done} onPress={()=>void call('complete',{id}).catch(error=>Alert.alert('Could not complete',error.message))}/><Button title="Edit plan" secondary onPress={()=>router.push({pathname:'/edit',params:{id}})}/><Button title="Delete plan" secondary onPress={remove}/></Page>;
}
