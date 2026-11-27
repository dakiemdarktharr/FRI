const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{_electron:electron}=require('../tests/node_modules/playwright');
const {readUsageGuide}=require('./scripts/read-usage-guide.cjs');
test('native shortcuts protect edits; widget create, move, resize and remove work by keyboard',{timeout:90000},async()=>{
 const data=fs.mkdtempSync(path.join(__dirname,'test-results/keyboard-')),env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_USER_DATA:data};delete env.ELECTRON_RUN_AS_NODE;
 const app=await electron.launch({executablePath:process.env.FRI_TEST_EXE||require('electron'),args:process.env.FRI_TEST_EXE?[]:[__dirname],env,timeout:20000});
 try{
  const p=await app.firstWindow();await readUsageGuide(p);await p.waitForFunction(()=>window.FRI_COMMAND);await p.evaluate(()=>FRI_COMMAND('schedule'));
  await p.locator('[name=title]').fill('Keep this draft');
  await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows()[0].webContents.send('fri:command','search'));
  assert.equal(await p.locator('[name=title]').inputValue(),'Keep this draft');
  await p.keyboard.press('Escape');await p.locator('#discard-edit').click();
  const selectionPromise=app.waitForEvent('window');await p.evaluate(()=>friDesktop.createWidget());const select=await selectionPromise;await select.waitForLoadState();
  await select.keyboard.press('ArrowLeft');await select.keyboard.press('Shift+ArrowRight');const area=await select.locator('#area').boundingBox();assert.equal(area.width,370);
  const widgetPromise=app.waitForEvent('window');await select.keyboard.press('Enter').catch(e=>{if(!select.isClosed())throw e});const widget=await widgetPromise;await widget.waitForLoadState();await widget.locator('#options').waitFor();
  const bounds=()=>widget.evaluate(()=>friWidget.bounds());
  await widget.locator('header').focus();const before=await bounds();await widget.keyboard.press('ArrowRight');await widget.waitForFunction(x=>friWidget.bounds().then(b=>b.x===x),before.x+10);
  await widget.locator('.resize').focus();const size=await bounds();await widget.keyboard.press('Shift+ArrowRight');await widget.waitForFunction(w=>friWidget.bounds().then(b=>b.width===w),size.width+40);
  await widget.locator('#options').focus();const prior=await bounds();await widget.keyboard.press('ArrowDown');await widget.keyboard.press('ArrowDown');assert.deepEqual(await bounds(),prior,'menu keys do not move widget');
  await widget.keyboard.press('Escape');assert.equal(await widget.locator('#options').evaluate(e=>e===document.activeElement),true);
  await widget.keyboard.press('Enter');await widget.keyboard.press('End');const closed=widget.waitForEvent('close');await widget.keyboard.press('Enter').catch(e=>{if(!widget.isClosed())throw e});await closed;
  await p.waitForFunction(()=>FRI_PREVIEW.getState().settings.desktopWidgets.length===0);assert.equal(await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().filter(w=>w.webContents.getURL().includes('widget.html')).length),0);
 }finally{await app.close()}
});
