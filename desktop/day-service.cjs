'use strict';
const core=require('./day-core.cjs'),{MODEL,REASONING_EFFORT,readConfig,rankCards}=require('./day-provider.cjs');
function createDayService({store,changed=()=>{},configFile,configLoader=()=>readConfig(configFile),fetchImpl=fetch,now=()=>new Date(),timeoutMs=45000}){
 const cache=new Map();let inFlight=null,lastAttempt=0,budgetDay='',calls=0;
 const local=(analysis,status)=>({...analysis,mode:'local',status});
 const signature=cards=>cards.map(c=>c.id+':'+c.priority).join('|');
 async function analyze(){
  const state=store.read().state;let clock=now(),analysis=core.analyze(state,clock);
  if(state?.settings?.dayOpenAIEnabled!==true)return local(analysis,'Đang xử lý trên thiết bị. OpenAI Luna Max chưa được bật.');
  const config=await configLoader(),currentState=store.read().state;clock=now();const current=core.analyze(currentState,clock);
  if(currentState?.settings?.dayOpenAIEnabled!==true)return local(current,'OpenAI Luna Max đã tắt; Day xử lý trên thiết bị.');
  if(!config.apiKey||config.invalid)return local(current,'Chưa có cấu hình OpenAI Luna Max hợp lệ. Gợi ý trên thiết bị vẫn hoạt động.');
  if(current.fingerprint!==analysis.fingerprint||signature(current.cards)!==signature(analysis.cards))return local(current,'Lịch đã đổi; Day kiểm tra lại trên thiết bị trước khi gửi OpenAI Luna Max.');
  analysis=current;
  if(!analysis.cards.length)return local(analysis,'Chưa có trùng lịch hoặc deadline trong 24 giờ tới.');
  const key=analysis.fingerprint+':'+signature(analysis.cards);
  const hit=cache.get(key);if(hit&&+clock-hit.at<900000)return {...analysis,cards:order(analysis.cards,hit.ids),mode:'openai',status:'OpenAI Luna Max đã sắp thứ tự gợi ý; các khung giờ được Fri kiểm tra trên thiết bị.'};
  if(inFlight){await inFlight;return latest(analysis,key);}
  const day=clock.toISOString().slice(0,10);if(day!==budgetDay){budgetDay=day;calls=0}if(calls>=30||+clock-lastAttempt<60000)return local(analysis,'Đang giữ giới hạn gọi OpenAI Luna Max; gợi ý trên thiết bị vẫn cập nhật.');
  lastAttempt=+clock;calls++;
  inFlight=(async()=>{try{const ids=await rankCards(analysis.cards,config,{fetchImpl,timeoutMs});cache.set(key,{ids,at:+clock});while(cache.size>20)cache.delete(cache.keys().next().value)}catch{/* Provider errors never contain calendar content or credentials in UI/logs. */}})();
  try{await inFlight}finally{inFlight=null}
  return latest(analysis,key);
 }
 function latest(previous,key){const state=store.read().state,current=core.analyze(state,now());if(current.fingerprint!==previous.fingerprint||signature(current.cards)!==signature(previous.cards)||state?.settings?.dayOpenAIEnabled!==true)return local(current,'Lịch đã đổi; Day đã kiểm tra lại trên thiết bị.');const result=cache.get(key);return result?{...current,cards:order(current.cards,result.ids),mode:'openai',status:'OpenAI Luna Max đã sắp thứ tự gợi ý; các khung giờ được Fri kiểm tra trên thiết bị.'}:local(current,'OpenAI Luna Max chưa phản hồi hợp lệ. Day tiếp tục kiểm tra trên thiết bị.');}
 function order(cards,ids){const ranks=new Map(ids.map((id,i)=>[id,i]));return [...cards].sort((a,b)=>a.priority-b.priority||ranks.get(a.id)-ranks.get(b.id))}
 return {async call(action,input){
  if(action==='day-status'){const config=await configLoader();return {configured:!!config.apiKey&&!config.invalid,model:MODEL,reasoningEffort:REASONING_EFFORT,cloudEnabled:store.read().state?.settings?.dayOpenAIEnabled===true}}
  if(action==='day-analyze')return analyze();
  if(action==='day-apply'){const result=await store.transaction(state=>core.applyMove(state,input,now()));changed();return result}
  throw Error('Unknown Day service');
 }};
}
module.exports={createDayService};
