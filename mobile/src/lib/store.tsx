import React,{createContext,useCallback,useContext,useEffect,useState,useRef} from 'react';
import {AppState,useColorScheme} from 'react-native';
import {call,dateKey,listen,Snapshot} from './fri';
type Store={data:Snapshot|null;error:string;refresh:(day?:string)=>Promise<void>;colors:typeof light};
const light={bg:'#F4F7FA',paper:'#FFFFFF',ink:'#172B3A',muted:'#586D7C',line:'#DBE4EB',control:'#7B8B98',accent:'#087F8C',onAccent:'#FFFFFF',tint:'#E0F2F2'};
const dark={bg:'#14181f',paper:'#222833',ink:'#f2f4f8',muted:'#b3bece',line:'#465368',control:'#7D8BA1',accent:'#75d8cc',onAccent:'#14181f',tint:'#203d3b'};
const Context=createContext<Store>({data:null,error:'',refresh:async()=>{},colors:light});
export function FriProvider({children}:{children:React.ReactNode}){const[data,setData]=useState<Snapshot|null>(null);const[error,setError]=useState('');const scheme=useColorScheme();const selected=useRef(dateKey());const serial=useRef(0);const refresh=useCallback(async(day?:string)=>{if(day)selected.current=day;const request=++serial.current;try{const next=await call<Snapshot>('snapshot',{day:selected.current});if(request===serial.current){setData(next);setError('')}}catch(e){if(request===serial.current)setError((e as Error).message)}},[]);useEffect(()=>{void refresh();const event=listen(()=>void refresh());const app=AppState.addEventListener('change',state=>{if(state==='active')void refresh()});return()=>{event.remove();app.remove()}},[refresh]);const theme=data?.preferences.theme??'system';return <Context.Provider value={{data,error,refresh,colors:theme==='dark'||(theme==='system'&&scheme==='dark')?dark:light}}>{children}</Context.Provider>}
export const useFri=()=>useContext(Context);
