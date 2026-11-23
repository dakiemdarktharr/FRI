const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {_electron:electron}=require('../tests/node_modules/playwright');
test('Day receives native state changes, applies through IPC, and persists across restart',async()=>{
 const results=path.join(__dirname,'test-results');fs.mkdirSync(results,{recursive:true});
 const profile=fs.mkdtempSync(path.join(results,'day-profile-'));
 const env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_USER_DATA:profile};delete env.ELECTRON_RUN_AS_NODE;
 const options={executablePath:require('electron'),args:[__dirname],env};let app=await electron.launch(options);
 try{
  const p=await app.firstWindow(),errors=[];p.on('pageerror',e=>errors.push(e.message));await p.waitForFunction(()=>window.FRI_PREVIEW);
  await p.evaluate(async()=>{
   const {state}=await friDesktop.loadState(),next=structuredClone(state);
   const tomorrow=new Date();tomorrow.setDate(tomorrow.getDate()+1);
   const key=d=>[d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');
   const due=new Date(Date.now()+3600000);
   const base={date:key(tomorrow),kind:'schedule',duration:60,done:false,category:'Work',location:'',notes:''};
   next.tasks=[{...base,id:'fixed-native',title:'Họp nhóm',time:'09:00',imported:true},{...base,id:'focus-native',title:'Viết báo cáo',time:'09:30',duration:30,flexible:true,flexibleUntil:'12:00'},{...base,id:'due-native',title:'Nộp báo cáo',kind:'deadline',date:key(due),time:String(due.getHours()).padStart(2,'0')+':'+String(due.getMinutes()).padStart(2,'0'),duration:0}];
   next.settings.dayOpenAIEnabled=false;next.settings.dayDismissed=[];await friDesktop.saveState(state,next);
  });
  await p.waitForFunction(()=>document.querySelector('[data-day-count]').textContent==='2');
  await p.locator('[data-action=day]').first().click();await p.locator('[data-day-apply]').waitFor();
  assert.equal(await p.locator('[name=message]').count(),0);
  await p.screenshot({path:path.join(results,'day-native.png')});
  await p.locator('[data-day-apply]').click();
  await p.waitForFunction(()=>FRI_PREVIEW.getState().tasks.find(t=>t.id==='focus-native').time==='10:00');
  assert.equal(await p.evaluate(async()=>{const {state}=await friDesktop.loadState();return state.tasks.find(t=>t.id==='fixed-native').time}),'09:00');
  assert.deepEqual(errors,[]);
  await app.close();app=await electron.launch(options);const reopened=await app.firstWindow();await reopened.waitForFunction(()=>window.FRI_PREVIEW);
  assert.equal(await reopened.evaluate(()=>FRI_PREVIEW.getState().tasks.find(t=>t.id==='focus-native').time),'10:00');
 }finally{await app.close().catch(()=>{})}
});
