'use strict';
// Optional one-request connectivity check. Sends synthetic facts only, never your calendar.
const path=require('node:path');
const {readConfig,rankCards,MODEL}=require('./desktop/day-provider.cjs');
(async()=>{
 const config=await readConfig(path.join(__dirname,'desktop/.env.day'));
 if(!config.apiKey||config.invalid){console.error('Fill OPENAI_API_KEY in desktop/.env.day and use DAY_MODEL=gpt-6-luna, DAY_REASONING_EFFORT=max.');process.exitCode=1;return}
 const started=Date.now();
 const cards=[{id:'synthetic-conflict',type:'conflict',title:'Hai lịch đang trùng nhau',body:'Synthetic test: Focus and Team meeting overlap at 10:00.',priority:1,move:{time:'11:00'}},{id:'synthetic-deadline',type:'deadline',title:'Deadline sắp tới',body:'Synthetic test: Demo submission at 16:00.',priority:2}];
 try{await rankCards(cards,config);console.log(JSON.stringify({provider:'OpenAI',model:MODEL,reasoningEffort:'max',success:true,elapsedMs:Date.now()-started}));}
 catch{console.error('OpenAI did not return a valid result within the configured limits. Check key permissions, model access and API billing. No calendar data was sent.');process.exitCode=1}
})();
