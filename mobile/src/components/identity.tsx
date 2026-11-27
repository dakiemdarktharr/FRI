import {Image,View,Text,ImageStyle} from 'react-native';
import {useFri} from '../lib/store';
const symbols={calendar:require('../../assets/symbol-calendar.png'),grid:require('../../assets/symbol-grid.png'),clock:require('../../assets/symbol-clock.png'),settings:require('../../assets/symbol-settings.png')};
export function Symbol({name,color,size=24}:{name:keyof typeof symbols;color:ImageStyle['tintColor'];size?:number}){return <Image accessible={false} source={symbols[name]} style={{width:size,height:size,tintColor:color}}/>}
export function Brand(){const{colors}=useFri();return <View accessibilityLabel="Fri" style={{flexDirection:'row',alignItems:'center',gap:2}}><Image accessible={false} source={require('../../assets/fri-symbol.png')} style={{width:40,height:40,tintColor:colors.accent}}/><Text style={{fontFamily:'Inter',fontWeight:'700',fontSize:30,letterSpacing:-2,color:colors.ink}}>fri.</Text></View>}
export function FirstPlanArt(){return <Image accessible={false} source={require('../../assets/first-plan.png')} resizeMode="contain" style={{width:170,height:114}}/>}

