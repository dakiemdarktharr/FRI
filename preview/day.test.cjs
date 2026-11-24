const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const path=require('node:path');
const http=require('node:http'),fs=require('node:fs'),{once}=require('node:events');
const {chromium,webkit}=require('../tests/node_modules/playwright');
let browser,server,appUrl;
before(async()=>{
 const html=fs.readFileSync(path.resolve(__dirname,'../FRI-liquid-glass.html'));
 server=http.createServer((req,res)=>res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'}).end(html));
 server.listen(0,'127.0.0.1');await once(server,'listening');appUrl=`http://127.0.0.1:${server.address().port}`;
 browser=await (process.env.FRI_BROWSER==='webkit'?webkit:chromium).launch();
});
after(async()=>{await browser?.close();await new Promise(resolve=>server?.close(resolve))});
const task=(id,title,time,duration,extra={})=>({id,title,date:'2030-01-01',time,duration,kind:'schedule',done:false,category:'Work',location:'',notes:'',...extra});
async function fresh(t,width=1200,fixedTitle='Họp nhóm'){
 // Seed a stable origin once. file: storage and reload behavior differ by engine;
 // an init script must never re-seed the old appointment during a reload.
 const tasks=[
  task('fixed',fixedTitle,'10:00',60,{imported:true,sourceKey:'calendar-1'}),
  task('focus','Viết báo cáo','10:30',45,{flexible:true,flexibleUntil:'12:00',planningOrigin:'focus'}),
  task('due','Nộp báo cáo','16:00',0,{kind:'deadline'})
 ];
 const initial={version:1,tasks,settings:{motion:false,glass:false,palette:'fri-v2',accent:'#955251',layout:'list',sidebar:'solid'},tabs:['2030-01-01'],active:'2030-01-01',drafts:[],finished:[],collections:['Work'],widgets:['upnext']};
 const context=await browser.newContext({viewport:{width,height:950},reducedMotion:'reduce',storageState:{cookies:[],origins:[{origin:appUrl,localStorage:[{name:'fri-liquid-preview-v1',value:JSON.stringify(initial)}]}]}});t.after(()=>context.close());
 const p=await context.newPage();await p.clock.install({time:new Date('2030-01-01T08:00:00')});
 await p.goto(appUrl);await p.waitForFunction(()=>window.FRI_PREVIEW);
 return p;
}
test('automatically detects conflict and deadline; applies only flexible task without a prompt',async t=>{
 const p=await fresh(t);const errors=[];p.on('pageerror',e=>errors.push(e.message));
 assert.equal(await p.locator('[data-day-count]').textContent(),'2');
 await p.evaluate(()=>FRI_COMMAND('insights'));assert.equal(await p.locator('[data-day-card]').count(),2);
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
 await p.evaluate(()=>FRI_COMMAND('insights'));
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
 await p.evaluate(()=>FRI_COMMAND('insights'));
 assert.equal(await p.locator('[data-day-card]').count(),2);
 assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth),390);
 await p.screenshot({path:path.resolve(__dirname,'.build/day-mobile.png'),fullPage:true});
});
test('calendar titles render as text rather than executable HTML in Day',async t=>{
 // Seed before startup so pending application saves cannot overwrite the fixture.
 const title='<img src=x onerror="window.dayInjected=true">';
 const p=await fresh(t,1200,title);
 assert.equal(await p.evaluate(()=>FRI_PREVIEW.getState().tasks.find(t=>t.id==='fixed').title),title);
 await p.evaluate(()=>FRI_COMMAND('insights'));

 assert.equal(await p.locator('#day-panel img').count(),0);assert.equal(await p.evaluate(()=>window.dayInjected),undefined);
 assert.match(await p.locator('#day-panel').textContent(),/<img src=x/);
});
