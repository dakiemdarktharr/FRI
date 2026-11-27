import rules from '../generated/meeting-agent';
export type MeetingDraft={title:string;date:string|null;time:string|null;location?:string;timeHint?:string;relativeTime?:string};
const drafts=new Map<string,MeetingDraft>();
// Router can mount a second assistant before unmounting the first. Consume the
// native single-use handoff once, even when both screens request the same share.
let transfer:{token:string;until:number;value:Promise<{text:string}>}|undefined;
export function readSharedText(token:string,read:()=>Promise<{text:string}>){
 if(transfer?.token===token&&transfer.until>Date.now())return transfer.value;
 const value=read();transfer={token,until:Date.now()+600000,value};return value;
}
export function proposeMeetings(text:string, now=Date.now()):MeetingDraft[]{
 const lines=text.split(/\r?\n/).map(s=>s.trim()).filter(Boolean).slice(0,60);
 const found=new Map<string,MeetingDraft>();
 for(let i=0;i<lines.length;i++){
  if(lines[i].length>480)continue;
  const item=rules.proposeDraft(lines[i],now)||rules.recognize(lines[i],lines[i-1]||'',now);
  if(item){const key=JSON.stringify(item);if(!found.has(key))found.set(key,item)}
 }
 return [...found.values()].slice(0,8);
}
export function stageMeeting(draft:MeetingDraft){const key=`${Date.now()}-${Math.random().toString(36).slice(2)}`;drafts.clear();drafts.set(key,draft);return key}
export function getMeeting(key?:string){return key?drafts.get(key):undefined}
export function clearMeeting(key?:string){if(key)drafts.delete(key)}
