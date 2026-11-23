const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const {chromium,webkit}=require('../tests/node_modules/playwright');
let browser;
before(async()=>{browser=await (process.env.FRI_BROWSER==='webkit'?webkit:chromium).launch()});
after(async()=>{await browser?.close()});
const task=(id,title,time,duration,extra={})=>({id,title,date:'2030-01-01',time,duration,kind:'schedule',done:false,category:'Work',location:'',notes:'',...extra});
async function fresh(t,width=1200){
 const context=await browser.newContext({viewport:{width,height:950},reducedMotion:'reduce'});t.after(()=>context.close());
 const p=await context.newPage();await p.clock.install({time:new Date('2030-01-01T08:00:00')});
 await p.addInitScript(tasks=>{if(!localStorage.getItem('fri-liquid-preview-v1'))localStorage.setItem('fri-liquid-preview-v1',JSON.stringify({version:1,tasks,settings:{motion:false,glass:false,palette:'fri-v2',accent:'#955251',layout:'list',sidebar:'solid'},tabs:['2030-01-01'],active:'2030-01-01',drafts:[],finished:[],collections:['Work'],widgets:['upnext']}))},[
  task('fixed','Họp nhóm','10:00',60,{imported:true,sourceKey:'calendar-1'}),
  task('focus','Viết báo cáo','10:30',45,{flexible:true,flexibleUntil:'12:00',planningOrigin:'focus'}),
  task('due','Nộp báo cáo','16:00',0,{kind:'deadline'})
 ]);
 await p.goto(pathToFileURL(path.resolve(__dirname,'../FRI-liquid-glass.html')).href);await p.waitForFunction(()=>window.FRI_PREVIEW);
 return p;
}
test('automatically detects conflict and deadline; applies only flexible task without a prompt',async t=>{
 const p=await fresh(t);const errors=[];p.on('pageerror',e=>errors.push(e.message));
 assert.equal(await p.locator('[data-day-count]').textContent(),'2');
 await p.locator('[data-action=day]').first().click();assert.equal(await p.locator('[data-day-card]').count(),2);
 assert.equal(await p.locator('[name=message]').count(),0);
 await p.locator('[data-day-apply]').click();
 await p.waitForFunction(()=>FRI_PREVIEW.getState().tasks.find(t=>t.id==='focus').time==='09:00');
 assert.equal(await p.evaluate(()=>FRI_PREVIEW.getState().tasks.find(t=>t.id==='fixed').time),'10:00');
 assert.equal(await p.locator('[data-day-card]').count(),1);
 await p.locator('[data-day-dismiss]').click();assert.equal(await p.locator('[data-day-card]').count(),0);
 await p.evaluate(()=>FRI_PREVIEW.flush());
 const persisted=await p.evaluate(()=>JSON.parse(localStorage.getItem('fri-liquid-preview-v1')));
 assert.equal(persisted.tasks.find(t=>t.id==='focus').time,'09:00');
 assert.equal(persisted.settings.dayDismissed.length,1);
 await p.reload();await p.waitForFunction(()=>window.FRI_PREVIEW);
 assert.equal(await p.evaluate(()=>FRI_PREVIEW.getState().tasks.find(t=>t.id==='focus').time),'09:00');
 await p.locator('[data-action=day]').first().click();
 assert.equal(await p.locator('[data-day-card]').count(),0);
 await p.locator('.day-options summary').click();await p.locator('[data-day-reset]').click();assert.equal(await p.locator('[data-day-card]').count(),1);
 assert.deepEqual(errors,[]);
});
test('editing an imported event keeps provenance and disallows flexible flag',async t=>{
 const p=await fresh(t);await p.locator('[data-action=detail][data-id=fixed]').first().click();await p.locator('[data-action=edit][data-id=fixed]').click();
 assert.equal(await p.locator('[name=flexible]').isDisabled(),true);
 await p.locator('[name=title]').fill('Họp nhóm cập nhật');await p.locator('[name=time]').fill('13:00');await p.getByRole('button',{name:'Save changes'}).click();
 await p.locator('#modal').waitFor({state:'hidden'});
 const event=await p.evaluate(()=>FRI_PREVIEW.getState().tasks.find(t=>t.id==='fixed'));assert.equal(event.sourceKey,'calendar-1');assert.equal(event.imported,true);assert.equal(event.flexible,false);
});
test('mobile Day panel escapes calendar content and stays within viewport',async t=>{
 const p=await fresh(t,390);
 await p.locator('[data-action=day]').first().click();
 assert.equal(await p.locator('[data-day-card]').count(),2);
 assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth),390);
 await p.screenshot({path:path.resolve(__dirname,'.build/day-mobile.png'),fullPage:true});
});
test('calendar titles render as text rather than executable HTML in Day',async t=>{
 const p=await fresh(t);
 await p.evaluate(()=>{const state=FRI_PREVIEW.getState();state.tasks[0].title='<img src=x onerror="window.dayInjected=true">';localStorage.setItem('fri-liquid-preview-v1',JSON.stringify(state))});
 await p.reload();await p.waitForFunction(()=>window.FRI_PREVIEW);await p.locator('[data-action=day]').first().click();
 assert.equal(await p.locator('#day-panel img').count(),0);assert.equal(await p.evaluate(()=>window.dayInjected),undefined);
 assert.match(await p.locator('#day-panel').textContent(),/<img src=x/);
});
