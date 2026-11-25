import {useEffect,useState} from 'react';
import {ActivityIndicator,TextInput} from 'react-native';
import {router,useLocalSearchParams} from 'expo-router';
import {Page,Label,Button,Card} from '../components/ui';
import {useFri} from '../lib/store';
import {call} from '../lib/fri';
import {MeetingDraft,proposeMeetings,stageMeeting,readSharedText} from '../lib/meeting';

export default function Assistant(){
 const{share}=useLocalSearchParams<{share?:string}>();const{colors}=useFri();
 const[text,setText]=useState('');const[items,setItems]=useState<MeetingDraft[]>([]);const[loadedShare,setLoadedShare]=useState<string>();const[message,setMessage]=useState('');const busy=!!share&&loadedShare!==share;
 function read(value:string){setItems(proposeMeetings(value));setMessage('');setLoadedShare(share)}
 useEffect(()=>{let live=true;if(share){void readSharedText(share,()=>call<{text:string}>('takeMeetingShare',{token:share})).then(r=>{if(live){setText(r.text);setItems(proposeMeetings(r.text));setMessage('');setLoadedShare(share)}}).catch(()=>{if(live){setText('');setItems([]);setMessage('This share has expired. Share it to Fri again.');setLoadedShare(share)}})}return()=>{live=false}},[share]);
 return <Page><Label large>Make it a plan.</Label>
 <Card><Label>Invitation</Label><TextInput accessibilityLabel="Invitation" placeholder="Tomorrow at 7 pm, coffee?" placeholderTextColor={colors.muted} multiline maxLength={12000} value={busy?'':text} editable={!busy} onChangeText={v=>{setText(v);setItems([]);setMessage('')}} style={{color:colors.ink,fontFamily:'Inter',fontSize:17,minHeight:120,textAlignVertical:'top',padding:8}}/>
 {!items.length?<Button title="Find plans" disabled={busy||!text.trim()} onPress={()=>{read(text);if(!proposeMeetings(text).length)setMessage('No clear invitation found. Include an activity and a date or time, or create a plan manually.')}}/>:null}</Card>
 {busy?<ActivityIndicator color={colors.accent} accessibilityLabel="Reading shared content"/>:null}
 {message?<Label>{message}</Label>:null}
 {(busy?[]:items).map((item,i)=><Card key={i}><Label>{item.title}</Label><Label muted>{item.date||'Choose a date'} · {item.time||item.timeHint&&`${item.timeHint} — confirm AM or PM`||'Choose a time'}</Label>{item.location?<Label muted>{item.location}</Label>:null}<Button title="Review plan" onPress={()=>router.push({pathname:'/edit',params:{meeting:stageMeeting(item)}})}/></Card>)}
 
 {!items.length?<Button title="Create manually" disabled={busy} secondary onPress={()=>router.push('/edit')}/>:null}
 </Page>
}
