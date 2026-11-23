import { requireNativeModule } from 'expo-modules-core';
export type FriEvent={id:string;calendarId:string;title:string;allDay:boolean;startUtc:number;endUtc:number;zone:string;startDate:string;endDate:string;location:string;notes:string;done:boolean;createdAt:number;updatedAt:number};
export type Template='today_agenda'|'next_event';
export type Snapshot={today:string;zone:string;events:FriEvent[];agenda:FriEvent[];calendars:{id:string;name:string;color:string}[];presets:{id:string;name:string;template:Template}[];instances:{id:number;template:Template;configured:boolean}[];requests:{token:string;state:string;template:Template}[];preferences:Record<string,string>};
const native=requireNativeModule<{call:(operation:string,payload:string)=>Promise<string>;addListener:(name:string,callback:()=>void)=>{remove:()=>void}}>('FriAndroid');
export async function call<T=Record<string,never>>(operation:string,payload:object={}):Promise<T>{const reply=JSON.parse(await native.call(operation,JSON.stringify(payload)));if(!reply.ok)throw new Error(reply.error);return reply.data as T}
export const listen=(cb:()=>void)=>native.addListener('onChange',cb);
export const dateKey=(d=new Date())=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
export const shiftDay=(day:string,n:number)=>{const d=new Date(`${day}T12:00:00`);d.setDate(d.getDate()+n);return dateKey(d)};
export function localTime(ms:number,zone:string){const parts=new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(ms);const p=(t:string)=>parts.find(i=>i.type===t)?.value;return `${p('year')}-${p('month')}-${p('day')}T${p('hour')}:${p('minute')}`}
export function eventTime(e:FriEvent,format='system'){return e.allDay?'All day':new Intl.DateTimeFormat(undefined,{hour:'numeric',minute:'2-digit',...(format==='system'?{}:{hour12:format==='12h'})}).format(e.startUtc)}
