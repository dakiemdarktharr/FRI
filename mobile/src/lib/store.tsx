import React,{createContext,useCallback,useContext,useEffect,useState,useRef} from 'react';
import {AppState,useColorScheme} from 'react-native';
import {call,dateKey,listen,Snapshot} from './fri';
type Store={data:Snapshot|null;error:string;refresh:(day?:string)=>Promise<void>;colors:typeof light};
const light={bg:'#FAF7F2',paper:'#FFFFFF',ink:'#302929',muted:'#76655E',line:'#E2D8D0',accent:'#955251',tint:'#EFE3DE'};
const dark={bg:'#211D1C',paper:'#302929',ink:'#FAF7F2',muted:'#C3B4AA',line:'#564842',accent:'#B97572',tint:'#493432'};
const Context=createContext<Store>({data:null,error:'',refresh:async()=>{},colors:light});
export function FriProvider({children}:{children:React.ReactNode}){const[data,setData]=useState<Snapshot|null>(null);const[error,setError]=useState('');const scheme=useColorScheme();const selected=useRef(dateKey());const serial=useRef(0);const refresh=useCallback(async(day?:string)=>{if(day)selected.current=day;const request=++serial.current;try{const next=await call<Snapshot>('snapshot',{day:selected.current});if(request===serial.current){setData(next);setError('')}}catch(e){if(request===serial.current)setError((e as Error).message)}},[]);useEffect(()=>{void refresh();const event=listen(()=>void refresh());const app=AppState.addEventListener('change',state=>{if(state==='active')void refresh()});return()=>{event.remove();app.remove()}},[refresh]);const theme=data?.preferences.theme??'system';return <Context.Provider value={{data,error,refresh,colors:theme==='dark'||(theme==='system'&&scheme==='dark')?dark:light}}>{children}</Context.Provider>}
export const useFri=()=>useContext(Context);
