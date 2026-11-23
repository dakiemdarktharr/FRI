const {test,before,after}=require('node:test');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium,webkit}=require('../tests/node_modules/playwright');
let browser;
before(async()=>{browser=await (process.env.FRI_BROWSER==='webkit'?webkit:chromium).launch()});
after(async()=>{await browser?.close()});
async function setup(t,{native=true,platform='win32',width=1100}={}){
 const context=await browser.newContext({viewport:{width,height:700},reducedMotion:'reduce'});t.after(()=>context.close());const page=await context.newPage();
 const shell=fs.readFileSync(path.join(__dirname,'shell.html'),'utf8'),header=shell.match(/<header class="app-titlebar"[\s\S]*?<\/header>/)[0];
 const css=['style.css','brand.css','updates.css'].map(f=>fs.readFileSync(path.join(__dirname,f),'utf8')).join('\n');
 await page.setContent(`<html><head><style>${css}</style></head><body><div id="app" class="app-window">${header}</div><div id="app-menu-popover" hidden></div><div id="toast" hidden role="status"></div></body></html>`);
 await page.evaluate(({native,platform})=>{
  window.updateCalls=[];window.FRI_PREVIEW={flush:async()=>{window.updateCalls.push('flush')}};
  window.updateFixture={phase:'idle',currentVersion:'0.6.0',latestVersion:null,percent:0,message:'',automatic:platform==='win32'};
  if(native)window.friDesktop={platform,material:'solid',onCommand:()=>()=>{},onWindowState:()=>()=>{},windowAction:async()=>{},onUpdateState:callback=>{window.emitUpdate=next=>{window.updateFixture=next;callback(next)};return()=>{}},updateAction:async action=>{
   window.updateCalls.push(action);
   if(action==='download'){window.emitUpdate({...window.updateFixture,phase:'downloading',percent:42});return new Promise(r=>window.finishDownload=()=>{window.emitUpdate({...window.updateFixture,phase:'ready',percent:100,message:'Ready to restart.'});r(window.updateFixture)})}
   if(action==='install'){window.emitUpdate({...window.updateFixture,phase:'installing',message:'Preparing restart…'});return window.updateFixture}
   return window.updateFixture;
  }};
 },{native,platform});
 await page.addScriptTag({content:fs.readFileSync(path.join(__dirname,'chrome.js'),'utf8')});return page;
}
test('titlebar update pill follows actual progress and waits for saves before install',async t=>{
 const p=await setup(t);assert.equal(await p.locator('#fri-update').isHidden(),true);
 await p.evaluate(()=>emitUpdate({...updateFixture,phase:'available',latestVersion:'0.7.0',message:'Download when ready.'}));
 await p.getByRole('button',{name:/Update v0.7.0/}).click();assert.match(await p.locator('#fri-update').textContent(),/Downloading 42%/);assert.equal(await p.locator('#fri-update').isDisabled(),true);
 assert.deepEqual(await p.evaluate(()=>updateCalls),['status','download']);
 await p.evaluate(()=>finishDownload());await p.getByRole('button',{name:/Restart to update/}).click();
 await p.waitForFunction(()=>updateCalls.includes('install'));assert.deepEqual(await p.evaluate(()=>updateCalls.slice(-2)),['flush','install']);
});
test('update button remains available after a failed save and never installs',async t=>{
 const p=await setup(t);await p.evaluate(()=>{FRI_PREVIEW.flush=async()=>{throw Error('private file')};emitUpdate({...updateFixture,phase:'ready',latestVersion:'0.7.0',message:'Ready.'})});
 await p.locator('#fri-update').click();await p.getByRole('status').filter({hasText:'not saved yet'}).waitFor();assert.equal(await p.evaluate(()=>updateCalls.includes('install')),false);assert.equal(await p.locator('#fri-update').isEnabled(),true);
});
test('manual mac download is explicit and update control fits beside native window controls',async t=>{
 const p=await setup(t,{platform:'darwin',width:640});await p.evaluate(()=>emitUpdate({...updateFixture,phase:'manual',latestVersion:'0.7.0',message:'Use the manual installer.'}));
 await p.getByRole('button',{name:/Download v0.7.0/}).click();assert.equal(await p.evaluate(()=>updateCalls.at(-1)),'open-releases');
 assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth),640);
 fs.mkdirSync(path.join(__dirname,'.build'),{recursive:true});await p.screenshot({path:path.join(__dirname,'.build/update-titlebar.png')});
});
test('web preview hides native updater and Help reports desktop requirement',async t=>{
 const p=await setup(t,{native:false});assert.equal(await p.locator('#fri-update').isHidden(),true);await p.locator('[data-menu=help]').click();await p.locator('[data-command=updates]').click();await p.getByRole('status').filter({hasText:'Install the FRI desktop app'}).waitFor();
});
