import {useRef,useState,type ElementRef} from 'react';
import {Modal,Pressable,ScrollView,Text,View,useWindowDimensions} from 'react-native';
import {useFri} from '../lib/store';
import {Button,Label} from './ui';
const STEP=44;
function Wheel({label,items,index,onChange}:{label:string;items:string[];index:number;onChange:(n:number)=>void}){
 const{colors}=useFri();const ref=useRef<ElementRef<typeof ScrollView>>(null),offset=useRef(index*STEP);
 function choose(n:number){const next=(n+items.length)%items.length;offset.current=next*STEP;onChange(next);ref.current?.scrollTo({y:next*STEP,animated:false})}
 return <View style={{flex:1}} accessible accessibilityRole="adjustable" accessibilityLabel={label} accessibilityValue={{text:items[index],min:0,max:items.length-1,now:index}} accessibilityActions={[{name:'increment'},{name:'decrement'}]} onAccessibilityAction={e=>choose(index+(e.nativeEvent.actionName==='increment'?1:-1))}>
 <ScrollView ref={ref} style={{height:STEP*5}} contentContainerStyle={{paddingVertical:STEP*2}} onLayout={()=>ref.current?.scrollTo({y:offset.current,animated:false})} showsVerticalScrollIndicator={false} snapToInterval={STEP} decelerationRate="fast" scrollEventThrottle={16} nestedScrollEnabled onScroll={e=>{offset.current=e.nativeEvent.contentOffset.y;onChange(Math.max(0,Math.min(items.length-1,Math.round(offset.current/STEP))))}}>
 {items.map((value,i)=><Pressable key={value} accessible={false} onPress={()=>choose(i)} style={{height:STEP,alignItems:'center',justifyContent:'center'}}><Text maxFontSizeMultiplier={1.3} style={{fontFamily:'BeVietnamPro',fontWeight:i===index?'600':'400',fontSize:25,color:i===index?colors.ink:colors.muted,fontVariant:['tabular-nums']}}>{value}</Text></Pressable>)}
 </ScrollView></View>
}
export function TimeWheel({value,onConfirm,onClose}:{value:string;onConfirm:(time:string)=>void;onClose:()=>void}){
 const{colors}=useFri(),{height}=useWindowDimensions(),[h,m]=value.split(':').map(Number);const[hour,setHour]=useState((h%12||12)-1),[minute,setMinute]=useState(m),[period,setPeriod]=useState(h<12?0:1);
 const hours=Array.from({length:12},(_,i)=>String(i+1).padStart(2,'0')),minutes=Array.from({length:60},(_,i)=>String(i).padStart(2,'0'));
 return <Modal transparent visible animationType="fade" onRequestClose={onClose} statusBarTranslucent>
 <View style={{flex:1,justifyContent:'center',alignItems:'center',backgroundColor:'#0008',padding:20}}>
 <View accessibilityViewIsModal style={{width:'100%',maxWidth:390,maxHeight:height-60,backgroundColor:colors.paper,borderRadius:26}}><ScrollView contentContainerStyle={{padding:24,gap:24}}>
 <View style={{flexDirection:'row',alignItems:'center',justifyContent:'space-between'}}><Label>Choose time</Label><Pressable accessibilityRole="button" accessibilityLabel="Close time picker" onPress={onClose} style={{height:44,width:44,borderRadius:12,alignItems:'center',justifyContent:'center',backgroundColor:colors.tint}}><Text style={{color:colors.ink,fontSize:25}}>×</Text></Pressable></View>
 <View style={{flexDirection:'row',height:STEP*5}}><View pointerEvents="none" style={{position:'absolute',top:STEP*2,left:0,right:0,height:STEP,borderRadius:12,backgroundColor:colors.tint,borderColor:colors.control,borderTopWidth:1,borderBottomWidth:1}}/><Wheel label="Hour" items={hours} index={hour} onChange={setHour}/><Wheel label="Minute" items={minutes} index={minute} onChange={setMinute}/><Wheel label="Period" items={['AM','PM']} index={period} onChange={setPeriod}/></View>
 <Button title="Confirm" onPress={()=>onConfirm(`${String((hour+1)%12+period*12).padStart(2,'0')}:${String(minute).padStart(2,'0')}`)}/>
 </ScrollView></View></View></Modal>
}
