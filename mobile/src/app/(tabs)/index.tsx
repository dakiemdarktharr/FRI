import {useCallback,useState} from 'react';
import {View,Text,Pressable} from 'react-native';
import {router,useLocalSearchParams,useFocusEffect} from 'expo-router';
import {Page,Label,Button,EventCard,Card} from '../../components/ui';
import {useFri} from '../../lib/store';
import {dateKey,shiftDay} from '../../lib/fri';
export default function Today(){
 const{data,refresh,colors}=useFri();const{date}=useLocalSearchParams<{date?:string}>();const day=date||dateKey();const[days,setDays]=useState(14);
 useFocusEffect(useCallback(()=>{void refresh(day)},[day,refresh]));
 return <Page><View style={{flexDirection:'row',justifyContent:'space-between',alignItems:'center'}}><View><Label large>Your days.</Label><Label muted>{new Date(`${day}T12:00`).toLocaleDateString('en',{month:'long',year:'numeric'})}</Label></View><Pressable accessibilityRole="button" accessibilityLabel="New plan" onPress={()=>router.push({pathname:'/edit',params:{date:day}})} style={{backgroundColor:colors.accent,width:50,height:50,borderRadius:16,alignItems:'center',justifyContent:'center'}}><Text style={{color:colors.onAccent,fontSize:28}}>+</Text></Pressable></View>
 {Array.from({length:days},(_,i)=>{const key=shiftDay(day,i),start=new Date(`${key}T00:00:00`).getTime(),end=new Date(`${shiftDay(key,1)}T00:00:00`).getTime();const events=(data?.events||[]).filter(e=>e.allDay?e.startDate<=key&&e.endDate>key:e.startUtc<end&&e.endUtc>start).sort((a,b)=>Number(b.allDay)-Number(a.allDay)||a.startUtc-b.startUtc);if(!events.length&&i>1)return null;return <View key={key} style={{gap:10,marginTop:12}}><View style={{flexDirection:'row',alignItems:'baseline',gap:10}}><Text style={{fontSize:18,fontWeight:'600',color:colors.ink}}>{key===dateKey()?'Today':key===shiftDay(dateKey(),1)?'Tomorrow':new Date(`${key}T12:00`).toLocaleDateString('en',{weekday:'long'})}</Text><Text style={{fontSize:13,color:colors.muted}}>{new Date(`${key}T12:00`).toLocaleDateString('en',{month:'short',day:'numeric'})}</Text></View>{events.length?events.map(e=><EventCard key={e.id} event={e}/>):<Card><Label muted>Nothing planned. Room for what matters.</Label></Card>}</View>})}
 <Button title="Show the next two weeks" secondary onPress={()=>setDays(d=>d+14)}/></Page>;
}
