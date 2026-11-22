const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {_electron:electron,chromium}=require('../tests/node_modules/playwright');
const results=path.join(__dirname,'test-results');fs.mkdirSync(results,{recursive:true});
async function windowState(app,property,expected){
  for(let i=0;i<60;i++){
    const actual=await app.evaluate(({BrowserWindow},property)=>BrowserWindow.getAllWindows()[0][property](),property);
    if(actual===expected)return;
    await new Promise(resolve=>setTimeout(resolve,100));
  }
  assert.fail(`Native ${property} did not become ${expected}`);
}

test('native window, isolated IPC, real commands and persistent calendar',async()=>{
  const data=fs.mkdtempSync(path.join(results,'profile-'));
  const env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_USER_DATA:data};delete env.ELECTRON_RUN_AS_NODE;
  const options={executablePath:process.env.FRI_TEST_EXE||require('electron'),args:process.env.FRI_TEST_EXE?[]:[__dirname],env};
  let app=await electron.launch(options);
  try{
    let p=await app.firstWindow();const errors=[];p.on('pageerror',e=>errors.push(e.message));
    await p.locator('.task').first().waitFor();
    assert.equal(await p.evaluate(()=>location.origin),'app://fri');
    assert.equal(await p.evaluate(()=>typeof require),'undefined');
    assert.equal(await p.evaluate(()=>typeof process),'undefined');
    assert.equal(await p.evaluate(()=>getComputedStyle(document.querySelector('.desktop')).display),'none');
    assert.equal(await p.evaluate(()=>document.documentElement.classList.contains('native-app')),true);
    const preferences=await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows()[0].webContents.getLastWebPreferences());
    assert.equal(preferences.contextIsolation,true);assert.equal(preferences.sandbox,true);assert.equal(preferences.nodeIntegration,false);assert.equal(preferences.webSecurity,true);
    assert.equal(await p.evaluate(()=>window.friDesktop.windowAction('invalid').then(()=>false,()=>true)),true);
    assert.equal(await p.evaluate(()=>window.friDesktop.openExternal('file:///C:/Windows/System32/cmd.exe').then(()=>false,()=>true)),true);
    await p.locator('[data-menu=new]').click();await p.locator('[data-command=deadline]').click();
    await p.locator('[name=title]').fill('Native deadline persistence');await p.locator('[name=time]').fill('09:30');
    await p.getByRole('button',{name:'Done',exact:true}).click();await p.locator('#modal').waitFor({state:'hidden'});
    const deadline=await p.evaluate(()=>FRI_PREVIEW.getState().tasks.find(t=>t.title==='Native deadline persistence'));
    assert.equal(deadline.kind,'deadline');assert.equal(deadline.duration,0);
    await p.locator('[data-action=search]').click();await p.locator('#search-input').fill('Native deadline');await p.locator('[data-action=search-result]').click();await p.locator('[data-action=close-modal]').first().click();
    await p.locator('[data-action=sidebar]').first().click();assert.equal(await p.locator('.sidebar-collapsed').count(),1);
    await p.locator('[data-action=sidebar]').first().click();
    await p.locator('[data-window=maximize]').click();await windowState(app,'isMaximized',true);
    await p.locator('[data-window=maximize]').click();await windowState(app,'isMaximized',false);
    await p.locator('[data-window=minimize]').click();await windowState(app,'isMinimized',true);
    await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows()[0].restore());
    await windowState(app,'isMinimized',false);
    await p.screenshot({path:path.join(results,'native-content.png')});
    assert.deepEqual(errors,[]);
    await app.close();app=await electron.launch(options);p=await app.firstWindow();await p.locator('.task').first().waitFor();
    assert.equal(await p.evaluate(()=>FRI_PREVIEW.getState().tasks.some(t=>t.title==='Native deadline persistence')),true);
    await p.locator('[data-window=close]').click();await app.process().exitCode;
  }finally{await app.close().catch(()=>{});}
});

test('monochrome UI, new plan types, menus, keyboard and safe restore',async()=>{
  const browser=await chromium.launch();
  try{
    const p=await browser.newPage({viewport:{width:1500,height:1000},reducedMotion:'reduce'});
    await p.goto(require('node:url').pathToFileURL(path.resolve(__dirname,'../FRI-liquid-glass.html')).href);
    await p.locator('.task').first().waitFor();
    for(const removed of ['.brand-caption','.local-label','#date-kicker','#progress-caption','#content-title','#collections','.task-note','.sidebar-note','.workspace-footer','.day-companion p'])assert.equal(await p.locator(removed).count(),0,removed);
    assert.equal(await p.locator('.brand-row [data-action=search]').count(),1);
    await p.locator('[data-menu=new]').click();await p.keyboard.press('ArrowDown');await p.keyboard.press('Enter');
    await p.getByRole('heading',{name:'New schedule',exact:true}).waitFor();await p.locator('[data-action=close-modal]').first().click();
    await p.locator('[data-menu=new]').click();await p.locator('[data-command=deadline]').click();
    await p.locator('[name=title]').fill('Submit the concept');await p.getByRole('button',{name:'Done',exact:true}).click();
    await p.getByRole('heading',{name:'When is it due?'}).waitFor();await p.locator('[name=answer]').fill('23:59');await p.getByRole('button',{name:/Continue/}).click();
    await p.locator('#modal').waitFor({state:'hidden'});
    assert.equal(await p.evaluate(()=>FRI_PREVIEW.getState().tasks.at(-1).duration),0);
    await p.keyboard.press('Control+f');await p.locator('#search-input').waitFor();await p.keyboard.press('Escape');
    const s=await p.evaluate(()=>FRI_PREVIEW.getState());s.tasks[0].id='"><img src=x onerror=alert(1)>';
    await p.locator('#backup-file').setInputFiles({name:'unsafe.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify({format:'fri-backup',schema:1,state:s}))});
    await p.getByRole('status').filter({hasText:'not a valid'}).waitFor();assert.equal(await p.locator('#restore-backup').count(),0);
    await p.screenshot({path:path.join(results,'web-monochrome.png'),fullPage:true});
    await p.evaluate(()=>document.documentElement.dataset.platform='darwin');
    await p.screenshot({path:path.join(results,'mac-chrome-preview.png'),fullPage:true});
    for(const width of [390,320]){await p.setViewportSize({width,height:900});assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth),width);}
  }finally{await browser.close();}
});
