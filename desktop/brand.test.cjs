const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{_electron}=require('../tests/node_modules/playwright');
test('opaque Fri surfaces retain translucent workspace and readable widget detail',async()=>{
 const env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_USER_DATA:fs.mkdtempSync(path.join(__dirname,'test-results/brand-'))};delete env.ELECTRON_RUN_AS_NODE;
 const app=await _electron.launch({executablePath:process.env.FRI_TEST_EXE||require('electron'),args:process.env.FRI_TEST_EXE?[]:[__dirname],env});
 try{const p=await app.firstWindow();await p.waitForFunction(()=>window.FRI_PREVIEW);await p.evaluate(()=>FRI_COMMAND('deadline'));await p.locator('[name=title]').fill('A clear, opaque plan');await p.locator('[name=time]').fill('23:00');await p.getByRole('button',{name:'Done',exact:true}).click();
 const surfaces=async selectors=>p.evaluate(list=>list.map(s=>{const el=document.querySelector(s);if(!el)throw Error('Missing '+s);const c=getComputedStyle(el);return {selector:s,color:c.backgroundColor,opacity:c.opacity,filter:c.backdropFilter}}),selectors);
 const assertOpaque=rows=>rows.forEach(r=>{assert.match(r.color,/^rgb\(/,r.selector);assert.equal(r.opacity,'1',r.selector)});
 assertOpaque(await surfaces(['.task','.task-open','.task-toggle','.date-card','.widget','.next-open','.new-button','.more-button']));
 const caption=await p.locator('.widget-caption').first().evaluate(el=>getComputedStyle(el).color);assert.equal(caption,'rgb(98, 84, 78)');
 const material=await p.locator('.main-material').evaluate(el=>getComputedStyle(el).backgroundColor);assert.match(material,/^rgba\(/);
 await p.evaluate(()=>FRI_COMMAND('widgets'));await p.waitForFunction(()=>getComputedStyle(document.querySelector('#modal')).opacity==='1');assertOpaque(await surfaces(['#modal','.menu-option']));assert.equal((await surfaces(['#modal']))[0].filter,'none');
 }finally{await app.close()}
});
