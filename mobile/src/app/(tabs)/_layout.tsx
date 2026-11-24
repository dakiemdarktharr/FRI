import {Tabs} from 'expo-router';
import {Text} from 'react-native';
import {useFri} from '../../lib/store';
export default function Layout(){const{colors}=useFri();return <Tabs screenOptions={{headerStyle:{backgroundColor:colors.bg},headerTintColor:colors.ink,headerShadowVisible:false,tabBarStyle:{backgroundColor:colors.paper,borderTopColor:colors.line},tabBarActiveTintColor:colors.accent,tabBarInactiveTintColor:colors.muted}}>{[['index','Feed','◷'],['calendar','Calendar','▦'],['widgets','Widgets','▣'],['settings','Settings','⚙']].map(([name,title,icon])=><Tabs.Screen key={name} name={name} options={{title,tabBarIcon:({color})=><Text style={{fontSize:22,color}}>{icon}</Text>}}/>)}</Tabs>}
