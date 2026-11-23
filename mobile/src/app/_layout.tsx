import {Stack} from 'expo-router';
import {FriProvider,useFri} from '../lib/store';
import {StatusBar} from 'expo-status-bar';
function Routes(){const{colors}=useFri();return <><StatusBar style={colors.bg==='#211D1C'?'light':'dark'}/><Stack screenOptions={{headerStyle:{backgroundColor:colors.bg},headerTintColor:colors.ink,headerShadowVisible:false,contentStyle:{backgroundColor:colors.bg}}}><Stack.Screen name="(tabs)" options={{headerShown:false}}/><Stack.Screen name="event" options={{title:'Your plan'}}/><Stack.Screen name="edit" options={{title:'Make a plan',presentation:'modal'}}/></Stack></>}
export default function Layout(){return <FriProvider><Routes/></FriProvider>}
