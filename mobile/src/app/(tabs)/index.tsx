import {useCallback} from 'react';
import {router,useLocalSearchParams,useFocusEffect} from 'expo-router';
import {Page,Label,Button,EventCard,Card} from '../../components/ui';
import {useFri} from '../../lib/store';
import {dateKey} from '../../lib/fri';
export default function Today(){const{data,refresh}=useFri();const{date}=useLocalSearchParams<{date?:string}>();const day=date||dateKey();useFocusEffect(useCallback(()=>{void refresh(day)},[day,refresh]));return <Page><Label large>{new Date(`${day}T12:00`).toLocaleDateString('en',{weekday:'long'})}</Label><Label muted>{new Date(`${day}T12:00`).toLocaleDateString('en',{month:'long',day:'numeric',year:'numeric'})}</Label><Button title="+ New plan" onPress={()=>router.push({pathname:'/edit',params:{date:day}})}/>{data?.agenda.length?data.agenda.map(e=><EventCard key={e.id} event={e}/>):<Card><Label>A little room for your day.</Label><Label muted>Add your first plan. It stays on this device.</Label></Card>}</Page>}
