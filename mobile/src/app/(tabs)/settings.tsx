import {router} from 'expo-router';
import {Alert} from 'react-native';
import {Page,Label,Card,Button} from '../../components/ui';
import {useFri} from '../../lib/store';
import {call} from '../../lib/fri';
export default function Settings(){
 const{data}=useFri();
 const save=(key:string,value:string)=>void call('preferences',{[key]:value}).catch(e=>Alert.alert('Settings',e.message));
 function choose(key:string,title:string,values:string[]){Alert.alert(title,undefined,values.map(value=>({text:value[0].toUpperCase()+value.slice(1),onPress:()=>save(key,value)})))}
 return <Page><Label large>Settings</Label>
 <Button title="Calendar assistant" secondary onPress={()=>router.push('/assistant')}/>
 <Card><Button title={'Appearance · '+(data?.preferences.theme??'system')} secondary onPress={()=>choose('theme','Appearance',['system','light','dark'])}/><Button title={'Time format · '+(data?.preferences.hourFormat??'system')} secondary onPress={()=>choose('hourFormat','Time format',['system','12h','24h'])}/></Card>
 </Page>
}
